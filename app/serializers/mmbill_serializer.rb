# frozen_string_literal: true

class MmbillSerializer < ApplicationSerializer
  attributes :bill_id,
    :congress,
    :bill_type,
    :number,
    :bill_uri,
    :title,
    :sponsor_title,
    :sponsor_id,
    :sponsor_name,
    :sponsor_state,
    :sponsor_uri,
    :gpo_pdf_uri,
    :congressdotgov_url,
    :introduced_date,
    :active,
    :house_passage,
    :cosponsors,
    :committees,
    :primary_subject,
    :summary,
    :summary_short,
    :latest_major_action_date,
    :latest_major_action,
    :senate_passage,
    :vetoed,
    :post_id,
    :topic_id,
    :short_title,
    :bill_slug,
    :actions,
    :versions

  def public
    true
  end

end
