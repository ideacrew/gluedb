class ExchangeInformation

  class MissingKeyError < StandardError
    def initialize(key)
      super("Missing required key: #{key}") 
    end
  end

  include Singleton

  REQUIRED_KEYS = [
    'amqp_uri',
    'receiver_id',
    'invalid_argument_queue',
    'processing_failure_queue',
    'request_exchange',
    'event_exchange',
    'event_publish_exchange',
    'environment',
    'hbx_id',
    'file_storage_uri'
  ]

  attr_reader :config

  # TODO: I have a feeling we may be using this pattern
  #       A LOT.  Look into extracting it if we repeat.
  def initialize
    @config = YAML.load(ERB.new(File.read(File.join(Rails.root,'config', 'exchange.yml'))).result)
    ensure_configuration_values(@config)
  end

  def ensure_configuration_values(conf)
    REQUIRED_KEYS.each do |k|
      if @config[k].blank?
        raise MissingKeyError.new(k)
      end
    end
  end

  def self.define_key(key)
    define_method(key.to_sym) do
      config[key.to_s]
    end
    self.instance_eval(<<-RUBYCODE)
      def self.#{key.to_s}
        self.instance.#{key.to_s}
      end
    RUBYCODE
  end

  REQUIRED_KEYS.each do |k|
    define_key k
  end
end
