class OrderShippingService
  def initialize(order, fulfillment_type:, shipping:, pending_offer: nil)
    @order = order
    @fulfillment_type = fulfillment_type
    @shipping_address = Address.new(shipping) if @fulfillment_type == Order::SHIP
    @buyer_name = shipping[:name]
    @buyer_phone_number = shipping[:phone_number]
    @pending_offer = pending_offer
    @order_data = OrderData.new(order)
  end

  def process!
    pre_process!

    Order.transaction do
      @order.update!(
        fulfillment_type: @fulfillment_type,
        buyer_phone_number: @buyer_phone_number,
        shipping_name: @buyer_name,
        shipping_address_line1: @shipping_address&.street_line1,
        shipping_address_line2: @shipping_address&.street_line2,
        shipping_city: @shipping_address&.city,
        shipping_region: @shipping_address&.region,
        shipping_country: @shipping_address&.country,
        shipping_postal_code: @shipping_address&.postal_code
      )
      # if user has pending offer, we want to set totals on pending offer
      # and not on the order yet
      @pending_offer.present? ? set_offer_totals! : set_order_totals!
      OrderTotalUpdaterService.new(@order).update_totals!
    end
  end

  private

  def pre_process!
    raise Errors::ValidationError.new(:invalid_state, state: @order.state) unless @order.state == Order::PENDING
    raise Errors::ValidationError, :invalid_state if @pending_offer.present? && @pending_offer.submitted_at?
  end

  def set_offer_totals!
    Offers::TotalUpdaterService.new(@pending_offer).process!
  end

  def set_order_totals!
    @order.update!(shipping_total_cents: @order_data.shipping_total_cents, tax_total_cents: tax_total_cents)
  end

  def tax_total_cents
    @tax_total_cents ||= begin
      @order.line_items.map do |li|
        artwork_address = Address.new(@order_data.artworks[li.artwork_id][:location])
        begin
          service = Tax::CalculatorService.new(li.total_amount_cents, li.effective_price_cents, li.quantity, @fulfillment_type, @shipping_address, @order_data.shipping_total_cents, artwork_address, @order_data.seller_locations)
          sales_tax = @order_data.partner[:artsy_collects_sales_tax] ? service.sales_tax : 0
          li.update!(sales_tax_cents: sales_tax, should_remit_sales_tax: service.artsy_should_remit_taxes?)
          sales_tax
        rescue Errors::ValidationError => e
          raise e unless e.code == :no_taxable_addresses

          # If there are no taxable addresses then we set the sales tax to 0.
          li.update!(sales_tax_cents: 0, should_remit_sales_tax: false)
          0
        end
      end.sum
    end
  end
end
