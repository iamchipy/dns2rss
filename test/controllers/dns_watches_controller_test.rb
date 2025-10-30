require "test_helper"

class DnsWatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "owner@example.com", password: "password123", password_confirmation: "password123")
    @viewer = User.create!(email: "viewer@example.com", password: "password123", password_confirmation: "password123")

    @public_watch = DnsWatch.create!(
      user: @viewer,
      domain: "public.example.com",
      record_type: "A",
      record_name: "@",
      interval_seconds: 300,
      next_check_at: Time.current,
      visibility: "public"
    )

    @owned_private_watch = DnsWatch.create!(
      user: @owner,
      domain: "owned-private.example.com",
      record_type: "A",
      record_name: "@",
      interval_seconds: 300,
      next_check_at: Time.current,
      visibility: "private"
    )

    @foreign_private_watch = DnsWatch.create!(
      user: @viewer,
      domain: "foreign-private.example.com",
      record_type: "A",
      record_name: "@",
      interval_seconds: 300,
      next_check_at: Time.current,
      visibility: "private"
    )
  end

  test "index shows only public watches to guests" do
    get dns_watches_url
    assert_response :success

    assert_select ".dns-watch-card__title", text: /public.example.com/
    assert_select ".dns-watch-card__title", text: /owned-private.example.com/, count: 0
  end

  test "index shows owned private watches to authenticated users" do
    get dns_watches_url, headers: session_for(@owner)
    assert_response :success

    assert_select ".dns-watch-card__title", text: /owned-private.example.com/
    assert_select ".dns-watch-card__title", text: /foreign-private.example.com/, count: 0
  end

  test "unauthenticated users cannot create watches" do
    assert_no_difference "DnsWatch.count" do
      post dns_watches_url,
           params: { dns_watch: { domain: "new.example.com", record_type: "A", record_name: "@", check_interval_minutes: 5, visibility: "private" } },
           as: :turbo_stream
    end

    assert_response :unauthorized
  end

  test "owners can create watches via turbo" do
    assert_difference "DnsWatch.count", 1 do
      post dns_watches_url,
           params: { dns_watch: { domain: "created.example.com", record_type: "A", record_name: "@", check_interval_minutes: 12, visibility: "private" } },
           headers: session_for(@owner),
           as: :turbo_stream
    end

    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, response.media_type

    created = DnsWatch.find_by(domain: "created.example.com")
    assert_equal @owner, created.user
    assert_equal "private", created.visibility
  end

  test "owners can update watches" do
    patch dns_watch_url(@owned_private_watch),
          params: { dns_watch: { visibility: "public", check_interval_minutes: 8 } },
          headers: session_for(@owner),
          as: :turbo_stream

    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, response.media_type

    @owned_private_watch.reload
    assert_equal "public", @owned_private_watch.visibility
    assert_equal 480, @owned_private_watch.interval_seconds
  end

  test "non owners cannot update watches" do
    patch dns_watch_url(@public_watch),
          params: { dns_watch: { visibility: "private" } },
          headers: session_for(@owner),
          as: :turbo_stream

    assert_response :not_found
  end

  test "owners can destroy watches" do
    assert_difference "DnsWatch.count", -1 do
      delete dns_watch_url(@owned_private_watch),
             headers: session_for(@owner),
             as: :turbo_stream
    end

    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, response.media_type
  end

  test "non owners cannot destroy watches" do
    assert_no_difference "DnsWatch.count" do
      delete dns_watch_url(@public_watch),
             headers: session_for(@owner),
             as: :turbo_stream
    end

    assert_response :not_found
  end

  test "public watches can be viewed via turbo" do
    get dns_watch_url(@public_watch), as: :turbo_stream

    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, response.media_type
  end

  test "private watches require ownership" do
    get dns_watch_url(@foreign_private_watch), as: :turbo_stream

    assert_response :not_found
  end

  private

  def session_for(user)
    { "rack.session" => { user_id: user.id } }
  end
end
