
# FIXME: PUT THESE IN GEM FILE
require 'net/http'
require 'net/https'
require 'cgi'
require 'iconv'

class ActionSmser::Base

  class << self
    def method_missing(method, *args) #:nodoc:
      return super unless respond_to?(method)
      new(method, *args)
    end

    def respond_to?(method, include_private = false) #:nodoc:
      super || public_instance_methods(true).include?(method.to_s)
    end

    # Only send messages in production
    def deliver_messages?
      Rails.env.production? || Rails.env.development?
    end

  end

  ##################################################################
  ## INSTANCE METHODS

  attr_accessor :body, :to, :from

  # Called from class.method_missing with own_sms_message when you call OwnMailer.own_sms_message
  def initialize(method_name, *args)
    @valid = true
    @sms_action = method_name
    send method_name, *args
  end

  # Main method for creating sms infos
  def sms(options)
    @body = options[:body]
    @to = options[:to]
    @from = options[:from]
  end

  def to_s
    "Sms #{self.class}.#{@sms_action} - From: #{from.inspect}, To: #{to.inspect}, Body: #{body.inspect}, Valid: #{@valid}"
  end

  # If you want mark the message as invalid
  def set_invalid
    @valid = false
  end

  def valid?
    @valid && !body.blank? && !@to.blank? && !@from.blank?
  end

  def delivery_options
    if @delivery_options.blank?
      ActionSmser.delivery_options
    end
  end
  def delivery_method
    ActionSmser::DeliveryMethods.const_get(delivery_options[:delivery_method].to_s.downcase.camelize)
  end


  def deliver
    return false unless valid?

    logger.info "Sending sms (#{self.to_s})"

    delivery_method.deliver(self)

    #SmsSentInfo.create_from_http_response(@response, self.sender, recipients_receive_sms, sms_type, self.message)
  end

  # http://en.wikipedia.org/wiki/GSM_03.38 , some chars takes 2 spaces
  def body_length
    i = 0
    body.to_s.chars.each do |char| i += DOUBLE_CHARS.include?(char) ? 2 : 1 end
    i
  end
  def body_cropped(max_length = 159)
    result = ""
    length = 0
    msg.to_s.chars.each do |char|
      length += DOUBLE_CHARS.include?(char) ? 2 : 1
      result << char if length <= max_length
    end
    result
  end
  # Most of the gateways want escaped and ISO encoded messages
  def body_encoded_escaped(cropped = true)
    message = (cropped ? body : body_cropped)
    CGI.escape(Iconv.iconv('ISO-8859-15//TRANSLIT//IGNORE', 'utf-8', message).to_s)
  end

  def to_encoded
    if @to.is_a?(Array)
      # harsh check that receivers are a list of numbers
      @to.collect{|number| number.to_i if number.to_i>1000}.compact.join(",")
    else
      @to.to_s
    end
  end

  def from_encoded
    @from
  end

  def logger
    ActionSmser::Logger
  end


end

