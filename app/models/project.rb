# == Schema Information
#
# Table name: projects
#
#  id               :integer         not null, primary key
#  type             :string(255)
#  projectable_id   :integer
#  projectable_type :string(255)
#  bike_id          :integer
#  created_at       :datetime
#  updated_at       :datetime
#

class Project < ActiveRecord::Base
  extend FriendlyId
  friendly_id :label

  validates_presence_of :bike_id

  belongs_to :bike, :inverse_of => :project
  belongs_to :projectable, :polymorphic => true
  belongs_to :project_category
  
  acts_as_commentable

  # Does a child class override this?
  #has_one :spec, :as => :specable

  attr_accessible nil

  def label
    (bike.nil?) ? bike_id : bike.number
  end

end
