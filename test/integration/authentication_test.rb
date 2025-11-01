# frozen_string_literal: true

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "complete signup and login flow" do
    # Visit signup page
    get signup_path
    assert_response :success
    assert_select "h2", "Sign Up"

    # Sign up with valid data
    assert_difference("User.count") do
      post users_path, params: { user: { email: "newuser@example.com", password: "password123", password_confirmation: "password123" } }
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_select "nav .layout__nav-item", text: /Signed in as newuser@example.com/

    # Log out
    delete logout_path
    assert_redirected_to root_path
    follow_redirect!
    assert_select "nav a", "Sign In"

    # Log back in
    post session_path, params: { user: { email: "newuser@example.com", password: "password123" } }
    assert_redirected_to root_path
    follow_redirect!
    assert_select "nav .layout__nav-item", text: /Signed in as newuser@example.com/
  end

  test "access protection for authenticated routes" do
    # Try to access create dns watch without being logged in
    post dns_watches_path, params: { dns_watch: { domain: "example.com", record_type: "A", record_name: "www" } }
    assert_redirected_to login_path
    assert_equal "Please sign in to continue.", flash[:alert]

    # Log in and try again
    user = users(:one)
    log_in_as(user)

    post dns_watches_path, params: { dns_watch: { domain: "example.com", record_type: "A", record_name: "www" } }
    assert_response :success
  end

  test "signup redirects when already logged in" do
    user = users(:one)
    log_in_as(user)

    get signup_path
    assert_redirected_to root_path
    assert_equal "You are already signed in.", flash[:notice]
  end

  test "login redirects when already logged in" do
    user = users(:one)
    log_in_as(user)

    get login_path
    assert_redirected_to root_path
    assert_equal "You are already signed in.", flash[:notice]
  end
end