# frozen_string_literal: true

require "rails_helper"

RSpec.describe CaptchaVerification do
  describe ".call" do
    it "returns true when the controller's reCAPTCHA check passes" do
      controller = instance_double(ApplicationController)
      allow(controller).to receive(:verify_recaptcha).and_return(true)
      expect(described_class.call(controller)).to be(true)
    end

    it "returns false when the controller's reCAPTCHA check fails" do
      controller = instance_double(ApplicationController)
      allow(controller).to receive(:verify_recaptcha).and_return(false)
      expect(described_class.call(controller)).to be(false)
    end
  end
end
