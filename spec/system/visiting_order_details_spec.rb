require 'rails_helper'

RSpec.describe 'visit order details', type: :system do
  let!(:order) do
    Fabricate(
      :order,
      seller_id: 'partner1',
      seller_type: 'partner',
      buyer_id: 'user1',
      buyer_type: 'user',
      created_at: 2.days.ago,
      updated_at: 1.day.ago,
      shipping_total_cents: 100_00,
      commission_fee_cents: 50_00,
      commission_rate: 0.10,
      seller_total_cents: 50_00,
      buyer_total_cents: 100_00,
      items_total_cents: 0,
      state: Order::PENDING,
      state_reason: nil
    )
  end
  before do
    stub_request(:get, 'http://exchange-test-gravity.biz/user/user1')
      .with(
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'User-Agent' => 'Faraday v0.15.3',
          'X-Xapp-Token' => 'https://media.giphy.com/media/yow6i0Zmp7G24/giphy.gif'
        }
      )
      .to_return(status: 200, body: {}.to_json, headers: {})

    stub_request(:get, 'http://exchange-test-gravity.biz/partner/partner1/all')
      .with(
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'User-Agent' => 'Faraday v0.15.3',
          'X-Xapp-Token' => 'https://media.giphy.com/media/yow6i0Zmp7G24/giphy.gif'
        }
      )
      .to_return(status: 200, body: {}.to_json, headers: {})
  end

  it 'renders order details page', js: true do
    order.save

    allow_any_instance_of(ApplicationController).to receive(:require_artsy_authentication)
    visit '/admin'

    page_title_selector = 'h2#page_title'

    expect(page).to have_selector(page_title_selector)

    row_selector = 'td.col.col-code'

    expect(page).to_not have_selector(row_selector)

    tab_selector = 'li.scope.all'
    within tab_selector do
      click_link 'All'
    end

    expect(page).to have_selector(row_selector)

    within row_selector do
      click_link order.code
    end

    expect(page).to have_selector(page_title_selector)

    within page_title_selector do
      expect(page).to have_content("Order #{order.id}")
    end
  end
end
