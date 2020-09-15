require_dependency "meritmoot_constraint"

Meritmoot::Engine.routes.draw do
  get "/" => "meritmoot#index", constraints: MeritmootConstraint.new
  get "/actions" => "actions#index", constraints: MeritmootConstraint.new
  get "/actions/:id" => "actions#show", constraints: MeritmootConstraint.new
  #get "/actions/bvotes" => "actions#getbvotes", constraints: MeritmootConstraint.new
  get "/bills/pdf" => "api#getpdf", constraints: MeritmootConstraint.new
  get "/reps" => "mmfollows#get", constraints: MeritmootConstraint.new
  get "/reps/search/:substr" => "api#memSearch", constraints: MeritmootConstraint.new
  put "/reps/:rep_id" => "mmfollows#put", constraints: MeritmootConstraint.new
  delete "/reps/:rep_id" => "mmfollows#delete", constraints: MeritmootConstraint.new
  post "/reps/:rep_id/votes" => "api#votes", constraints: MeritmootConstraint.new
end
