require 'rails_helper'

describe EnrollmentEvents::Batch, :dbclean => :after_each do

  subject { EnrollmentEvents::Batch }
  let(:parsed_event) { ExternalEvents::EnrollmentEventNotification.new(nil, nil, nil, body, nil) }
  let(:body) { <<-EVENTXML
     <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
     <header>
       <hbx_id>29035</hbx_id>
       <submitted_timestamp>2016-11-08T17:44:49</submitted_timestamp>
     </header>
     <event>
       <body>
         <enrollment_event_body xmlns="http://openhbx.org/api/terms/1.0">
           <affected_members>
           </affected_members>
           <enrollment xmlns="http://openhbx.org/api/terms/1.0">
             <policy>
               <id>
                 <id>123</id>
               </id>
               <enrollees>
                 <enrollee>
                   <member>
                     <id><id>1</id></id>
                   </member>
                   <is_subscriber>true</is_subscriber>
                   <benefit>
                     <premium_amount>111.11</premium_amount>
                     <begin_date>#{Date.today.next_year.beginning_of_year.strftime("%Y%m%d")}</begin_date>
                   </benefit>
                 </enrollee>
               </enrollees>
               <enrollment>
                 <plan>
                   <id>
                     <id>1</id>
                   </id>
                   <name>BluePreferred PPO Standard Platinum $0</name>
                   <active_year>2020</active_year>
                   <is_dental_only>false</is_dental_only>
                   <carrier>
                     <id>
                       <id>1</id>
                     </id>
                     <name>CareFirst</name>
                   </carrier>
                   <metal_level>urn:openhbx:terms:v1:plan_metal_level#platinum</metal_level>
                   <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
                   <ehb_percent>99.64</ehb_percent>
                 </plan>
                 <individual_market>
                   <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
                   <applied_aptc_amount>100.00</applied_aptc_amount>
                 </individual_market>
                 <premium_total_amount>56.78</premium_total_amount>
                 <total_responsible_amount>123.45</total_responsible_amount>
               </enrollment>
             </policy>
           </enrollment>
           </enrollment_event_body>
       </body>
     </event>
     </enrollment_event>
  EVENTXML
  }

  context ".new_batch?" do
    it "should return false when no record found" do
      expect(subject.new_batch?(parsed_event)).to eq false
    end

    it "should return true when record found" do
      subject.create_batch_and_yield(parsed_event) do
      end
      expect(subject.new_batch?(parsed_event)).to eq true
    end
  end

  context ".find_batch" do
    it "should return batch record" do
      subject.create_batch_and_yield(parsed_event) do
      end
      batch = subject.find_batch(parsed_event)
      expect(batch.subscriber_hbx_id).to eq "1"
    end
  end

  context ".create_batch_and_yield" do
    it "should create batch in open status" do
      subject.create_batch_and_yield(parsed_event) do
      end
      expect(EnrollmentEvents::Batch.count).to eq 1
      batch = EnrollmentEvents::Batch.first
      expect(batch.subscriber_hbx_id).to eq "1"
      expect(batch.benefit_kind).to eq "health"
      expect(batch.employer_hbx_id).to eq nil
      expect(EnrollmentEvents::Batch.first.aasm_state).to eq "open"
    end
  end

  context "batch transition" do
    it "open to pending_transmission status" do
      subject.create_batch_and_yield(parsed_event) do
      end
      batch = EnrollmentEvents::Batch.first
      batch.process!
      expect(batch.aasm_state).to eq "pending_transmission"
    end

    it "pending_transmission to closed status" do
      subject.create_batch_and_yield(parsed_event) do
      end
      batch = EnrollmentEvents::Batch.first
      batch.process!
      batch.transmit!
      expect(batch.aasm_state).to eq "closed"
    end

    it "pending_transmission to error status" do
      subject.create_batch_and_yield(parsed_event) do
      end
      batch = EnrollmentEvents::Batch.first
      batch.process!
      batch.exception!
      expect(batch.aasm_state).to eq "error"
    end

    it "error to pending_transmission status" do
      subject.create_batch_and_yield(parsed_event) do
      end
      batch = EnrollmentEvents::Batch.first
      batch.process!
      batch.exception!
      batch.process!
      expect(batch.aasm_state).to eq "pending_transmission"
    end
  end

  context ".create_batch_transaction_and_yield" do
    it "should create batch transactions" do
      subject.create_batch_and_yield(parsed_event) do
      end
      subject.create_batch_transaction_and_yield(parsed_event, body, nil, nil) do
      end
      batch = EnrollmentEvents::Batch.first
      expect(batch.transactions.count).to eq 1
    end
  end
end