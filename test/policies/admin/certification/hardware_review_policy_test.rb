require "test_helper"

class Admin::Certification::HardwareReviewPolicyTest < ActiveSupport::TestCase
  setup do
    @reviewer = create_user(slack_id: "U_HW_POLICY_REVIEWER", display_name: "hw_policy_reviewer")
    @reviewer.update!(granted_roles: [ "project_certifier" ])
  end

  test "show? is true for another user's hardware project" do
    owner = create_user(slack_id: "U_HW_POLICY_OWNER", display_name: "hw_policy_owner")
    project = hardware_project(owner: owner)

    assert Admin::Certification::HardwareReviewPolicy.new(@reviewer, project).show?
  end

  test "show? is false for a reviewer's own project" do
    project = hardware_project(owner: @reviewer)

    refute Admin::Certification::HardwareReviewPolicy.new(@reviewer, project).show?
  end

  test "show? is false for a non-reviewer" do
    non_reviewer = create_user(slack_id: "U_HW_POLICY_NON", display_name: "hw_policy_non")
    project = hardware_project(owner: non_reviewer)

    refute Admin::Certification::HardwareReviewPolicy.new(non_reviewer, project).show?
  end

  test "show? is false without a user" do
    project = hardware_project(owner: @reviewer)

    refute Admin::Certification::HardwareReviewPolicy.new(nil, project).show?
  end

  private

  def hardware_project(owner:)
    project = Project.create!(title: "HW policy #{SecureRandom.hex(4)}", hardware_stage: "design")
    Project::Membership.create!(project:, user: owner, role: :owner)
    project
  end
end
