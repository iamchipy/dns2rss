# frozen_string_literal: true

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get signup_path
    assert_response :success
    assert_select "h2", "Sign Up"
  end

  test "should create user with valid parameters" do
    assert_difference("User.count") do
      post users_path, params: { user: { email: "test@example.com", password: "password123", password_confirmation: "password123" } }
    end

    assert_redirected_to root_path
    assert_equal "Welcome! Your account has been created.", flash[:notice]
    assert session[:user_id].present?
  end

  test "should not create user with invalid email" do
    assert_no_difference("User.count") do
      post users_path, params: { user: { email: "invalid", password: "password123", password_confirmation: "password123" } }
    end

    assert_response :unprocessable_entity
  end

  test "should not create user with mismatched passwords" do
    assert_no_difference("User.count") do
      post users_path, params: { user: { email: "test@example.com", password: "password123", password_confirmation: "different" } }
    end

    assert_response :unprocessable_entity
  end

  test "should not create user with duplicate email" do
    existing_user = users(:one)

    assert_no_difference("User.count") do
      post users_path, params: { user: { email: existing_user.email, password: "password123", password_confirmation: "password123" } }
    end

    assert_response :unprocessable_entity
  end

  test "should redirect logged in user away from signup" do
    user = users(:one)
    log_in_as(user)

    get signup_path
    assert_redirected_to root_path
    assert_equal "You are already signed in.", flash[:notice]
  end
end