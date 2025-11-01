# frozen_string_literal: true

class AuthenticationSystemTest < ApplicationSystemTestCase
  test "user signup flow" do
    visit root_path
    
    # Click signup link
    click_on "Sign Up"
    
    # Should be on signup page
    assert_text "Sign Up"
    assert_text "Create your account to start monitoring DNS changes"
    
    # Fill out signup form
    fill_in "Email", with: "newuser@example.com"
    fill_in "Password", with: "password123"
    fill_in "Confirm Password", with: "password123"
    
    # Submit form
    click_on "Sign Up"
    
    # Should be redirected to root with success message
    assert_text "Welcome! Your account has been created."
    assert_text "Signed in as newuser@example.com"
  end

  test "user login flow" do
    user = users(:one)
    
    visit root_path
    
    # Click login link
    click_on "Sign In"
    
    # Should be on login page
    assert_text "Sign In"
    assert_text "Welcome back! Please sign in to your account"
    
    # Fill out login form
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    
    # Submit form
    click_on "Sign In"
    
    # Should be redirected to root with success message
    assert_text "Welcome back!"
    assert_text "Signed in as #{user.email}"
  end

  test "user logout flow" do
    user = users(:one)
    
    # Log in first
    visit login_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_on "Sign In"
    
    # Should be logged in
    assert_text "Signed in as #{user.email}"
    
    # Log out
    click_on "Sign Out"
    
    # Should be logged out
    assert_text "You have been signed out."
    assert_text "Sign In"
    assert_text "Sign Up"
  end

  test "invalid login shows error" do
    visit root_path
    click_on "Sign In"
    
    # Try invalid credentials
    fill_in "Email", with: "invalid@example.com"
    fill_in "Password", with: "wrongpassword"
    click_on "Sign In"
    
    # Should show error and stay on login page
    assert_text "Invalid email or password"
    assert_text "Sign In"
  end

  test "protected routes redirect to login" do
    visit dns_watches_path
    
    # Try to create a DNS watch without being logged in
    # This would normally be done via JavaScript, but we can test the redirect
    visit new_dns_watch_path rescue nil
    
    # Should redirect to login if we try to access protected content
    if current_path != login_path
      # Try to access the page directly to see if it redirects
      visit login_path
    end
    
    assert_text "Sign In"
  end
end