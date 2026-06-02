module Raffle
  module Referrals
    # Converts a pending referral once the referred platform user clears ID
    # verification: awards tickets to the referrer for the currently-active
    # week. Drops self-referrals (referred user's Hack Club email == the
    # referrer's GitHub email). Idempotent and order-independent.
    class Credit
      def self.run_safely(user)
        new(user).run
      rescue StandardError => e
        Rails.logger.error("[Raffle::Referrals::Credit] #{e.class}: #{e.message}")
        Sentry.capture_exception(e) if defined?(Sentry)
        nil
      end

      def initialize(user)
        @user = user
      end

      def run
        return unless @user.identity_verified?

        referral = Raffle::Referral.includes(:participant).find_by(referred_user_id: @user.id)
        return unless referral

        referral.with_lock do
          return referral if referral.status_verified? || referral.status_self_referral? || referral.status_rejected?

          if self_referral?(referral)
            referral.paper_trail_event = "mark_self_referral"
            referral.update!(status: :self_referral, tickets_awarded: 0, credited_week: nil)
            return referral
          end

          week = Raffle::Week.current
          return unless week

          referral.paper_trail_event = "credit_referral"
          referral.update!(
            status: :verified,
            tickets_awarded: 20,
            credited_week: week,
            verified_at: Time.current
          )
          referral
        end
      end

      private

      def self_referral?(referral)
        referrer_email = referral.participant.github_email
        return false if referrer_email.blank? || @user.email.blank?

        @user.email.casecmp?(referrer_email)
      end
    end
  end
end
