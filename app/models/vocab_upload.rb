class VocabUpload
  attr_accessor :kind
  attr_accessor :submitted_by
  attr_accessor :vocab
  attr_accessor :bypass_validation
  attr_accessor :csl_number
  attr_accessor :redmine_ticket

  ALLOWED_ATTRIBUTES = [:kind, :submitted_by, :vocab, :csl_number,  :redmine_ticket]

  include ActiveModel::Validations
  include ActiveModel::Conversion
  include ActiveModel::Naming

  validates_inclusion_of :kind, :in => ["maintenance", "initial_enrollment"], :allow_blank => false, :allow_nil => false
  validates_presence_of :submitted_by
  validates_presence_of :vocab

  def initialize(options={})
    options.each_pair do |k,v|
      if ALLOWED_ATTRIBUTES.include?(k.to_sym)
        self.send("#{k}=", v)
      end
    end
  end

  def save(listener)
    return(false) unless self.valid?
    file_data = vocab.read
    file_name = vocab.original_filename
    doc = Nokogiri::XML(file_data)
    change_request = Parsers::Xml::Enrollment::ChangeRequestFactory.create_from_xml(doc)
    plan = Plan.find_by_hios_id_and_year(change_request.hios_plan_id, change_request.plan_year)
    unless bypass_validation
      validations = [
        Validators::PremiumTotalValidatorFactory.create_for(change_request, listener),
        Validators::PremiumResponsibleValidator.new(change_request, listener),
        Validators::AptcValidator.new(change_request, plan, listener)
      ]

      if validations.any? { |v| v.validate == false }
        return false
      end
    end
    alter_npt_flag(change_request) if change_request.individual_market?
    log_upload(file_name, file_data)
    submit_cv(kind, file_name, file_data)
    true
  end

  # Changing the NPT indicator to false on a Policy with certain rules they are:
  # * If uploaded CV is for carefirst, initial transaction and it has existing terminated policy or canceled policy with term_for_np value as True
  # * If uploaded CV is for non-carefirst, maintenance(reinstate) and it has existing terminated policy or canceled policy with term_for_np value as True
  # @return [Boolean]
  def alter_npt_flag(change_request)
    begin
      policy = Policy.where(hbx_enrollment_ids: change_request.eg_id).first
      if change_request.hbx_carrier_id == "116036" #hbx_carrier_id of CareFirst carrier
        alter_carefirst_npt_flag(change_request, policy)
      else
        alter_non_carefirst_npt_flag(change_request, policy)
      end
    rescue Exception => e
      puts e.to_s
    end
  end

  def alter_carefirst_npt_flag(change_request, policy)
    reinstate_policy_m_id = change_request.subscriber_id
    pols = Person.where(authority_member_id: reinstate_policy_m_id).first.policies
    pols.each do |pol|
      if change_request.type == 'add' && change_request.reason.text == 'initial_enrollment' && pol.term_for_np == true && term_or_cancel_carefirst_policy_exists?(pol, change_request)
        pol.update_attributes!(term_for_np: false)
        Observers::PolicyUpdated.notify(pol)
      elsif change_request.cancel? && policy.aasm_state == 'submitted' && pol.versions.last.try(:term_for_np) == true && term_or_cancel_carefirst_policy_exists?(pol, change_request)
        pol.update_attributes!(term_for_np: true)
        Observers::PolicyUpdated.notify(pol)
      elsif change_request.reinstate? && policy.aasm_state == 'canceled' && pol.term_for_np == true && term_or_cancel_carefirst_policy_exists?(pol, change_request)
        pol.update_attributes!(term_for_np: false)
        Observers::PolicyUpdated.notify(pol)
      elsif change_request.terminate? && policy.aasm_state == 'terminated' && policy.term_for_np == true
        policy.update_attributes!(term_for_np: false)
        Observers::PolicyUpdated.notify(policy)
      end
    end
  end

  def term_or_cancel_carefirst_policy_exists?(pol, change_request)
    reinstate_policy_plan_id = change_request.plan_id
    reinstate_policy_carrier_id = change_request.carrier_id
    term_policy_end_date = change_request.begin_date - 1.day
    term_en_ids = pol.enrollees.map(&:m_id).sort
    reinstate_en_ids = change_request.affected_member_ids.sort
    return false unless pol.employer_id == nil
    return false unless (pol.aasm_state == "terminated" && pol.policy_end == term_policy_end_date)
    return false unless pol.plan_id.to_s == reinstate_policy_plan_id
    return false unless pol.carrier_id.to_s == reinstate_policy_carrier_id
    return false unless term_en_ids.count == reinstate_en_ids.count
    return false unless term_en_ids == reinstate_en_ids
    true
  end

  def alter_non_carefirst_npt_flag(change_request, policy)
    if change_request.reinstate? && policy.term_for_np == true
      policy.update_attributes!(term_for_np: false)
      Observers::PolicyUpdated.notify(policy)
    elsif change_request.cancel? && policy.aasm_state == 'resubmitted'
      unless policy.versions.empty?
        last_version_npt = policy.versions.last.term_for_np
        policy.update_attributes!(term_for_np: last_version_npt)
      end
    elsif change_request.terminate? && policy.aasm_state == 'terminated' && policy.term_for_np == true
      policy.update_attributes!(term_for_np: false)
      Observers::PolicyUpdated.notify(policy)
    end
  end

  def submit_cv(cv_kind, name, data)
    return if Rails.env.test?
    tag = (cv_kind.to_s.downcase == "maintenance")
    pubber = ::Services::CvPublisher.new(submitted_by)
    pubber.publish(tag, name, data)
  end

  def persisted?
    false
  end

  def log_upload(file_name, file_data)
    broadcast_info = {
      :routing_key => "info.events.legacy_enrollment_vocabulary.uploaded",
      :app_id => "gluedb",
      :headers => {
        "file_name" => file_name,
        "kind" =>  kind,
        "submitted_by"  => submitted_by,
        "bypass_validation" => bypass_validation.to_s
      }
    }
    if !csl_number.blank?
      broadcast_info[:headers]["csl_number"] = csl_number
    end
    if !redmine_ticket.blank?
      broadcast_info[:headers]["redmine_ticket"] = redmine_ticket
    end
    Amqp::EventBroadcaster.with_broadcaster do |eb|
      eb.broadcast(broadcast_info, file_data)
    end
  end
end
