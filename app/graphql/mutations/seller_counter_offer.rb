class Mutations::SellerCounterOffer < Mutations::BaseMutation
  null true

  argument :offer_id, ID, required: true
  argument :amount_cents, Integer, required: true

  field :order_or_error, Mutations::OrderOrFailureUnionType, 'A union of success/failure', null: false

  def resolve(offer_id:, amount_cents:)
    offer = Offer.find(offer_id)
    validate_request!(offer)
    order = offer.order

    pending_offer = OfferService.create_pending_offer(offer, amount_cents: amount_cents, from_type: order.seller_type, from_id: order.seller_id, creator_id: current_user_id)

    OfferService.submit_pending_offer(pending_offer)
    { order_or_error: { order: order.reload } }
  rescue Errors::ApplicationError => e
    { order_or_error: { error: Types::ApplicationErrorType.from_application(e) } }
  end

  private

  def validate_request!(offer)
    authorize_seller_request!(offer)
    raise Errors::ValidationError, :cannot_counter unless offer.awaiting_response_from == Order::SELLER
  end
end
