# frozen_string_literal: true

class MmrollcallSerializer < ApplicationSerializer
  attributes :mm_primary,
    :congress,
    :session,
    :chamber,
    :roll_call,
    :source,
    :url,
    :bill_id,
    :bill_number,
    :bill_title,
    :question,
    :description,
    :vote_type,
    :date,
    :time,
    :result,
    :document_number,
    :document_title,
    :democratic_yes,
    :democratic_no,
    :republican_yes,
    :republican_no,
    :total_yes,
    :total_no,
    :democratic_majority_position,
    :republican_majority_position,
    :topic_id,
    :post_id

  def public
    true
  end

end
