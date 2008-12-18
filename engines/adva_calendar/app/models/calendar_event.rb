
class CalendarEvent < ActiveRecord::Base
  has_many :assets, :through => :asset_assignments
  has_many :asset_assignments, :foreign_key => :content_id # TODO shouldn't that be :dependent => :delete_all?
  has_many :category_assignments, :foreign_key => 'content_id'
  has_many :categories, :through => :category_assignments
  belongs_to :location
  belongs_to :section
  alias :calendar :section
  belongs_to :user
  
  serialize :recurrence
  
  belongs_to :parent_event, :class_name => "CalendarEvent", :foreign_key => "parent_id"
  has_many :recurring_events, :class_name => "CalendarEvent", :foreign_key => "parent_id"

  has_permalink :title, :scope => :section_id
  acts_as_taggable
  acts_as_role_context :parent => Calendar

  filters_attributes :sanitize => :body_html, :except => [:body, :cached_tag_list]
  filtered_column :body

  validates_presence_of :startdate
  validates_presence_of :title
  validates_presence_of :user_id
  validates_presence_of :section_id
  validates_presence_of :location_id
  validates_uniqueness_of :permalink, :scope => :section_id
  
  before_create :set_published
  before_save :update_recurring_events

  named_scope :by_categories, Proc.new {|*category_ids| {:conditions => ['category_assignments.category_id IN (?)', category_ids], :include => :category_assignments}}
  named_scope :elapsed, lambda {{:conditions => ['startdate < ? AND (enddate IS ? OR enddate < ?)', Time.now, nil, Time.now], :order => 'startdate DESC'}}
  named_scope :upcoming, Proc.new {|startdate, enddate| {:conditions => ['(startdate > ? AND startdate < ?) OR (startdate < ? AND enddate > ?)', startdate||Time.now, enddate||((startdate||Time.now) + 1.month), startdate||Time.now, enddate||Time.now], :order => 'startdate ASC'}}
  named_scope :recently_added, lambda{{:conditions => ['startdate > ? OR (startdate < ? AND enddate > ?)', Time.now, Time.now, Time.now], :order => 'created_at DESC'}}

  named_scope :published, :conditions => {:draft => false }
  named_scope :search, Proc.new{|query, filter| {:conditions => ["#{CalendarEvent.sanitize_filter(filter)} LIKE ?", "%%%s%%" % query], :order => 'startdate DESC'}}

  def self.sanitize_filter(filter)
    %w(title body).include?(filter.to_s) ? filter.to_s : 'title'
  end
  def set_published
    self.published_at ||= Time.zone.now
  end

  def validate
    errors.add(:enddate, 'must be after start date') if ! self.enddate.nil? and self.enddate < self.startdate 
  end

  def update_recurring_events
    # We assume that recurring event are unique on a index of
    #   [parent_id, startdate, enddate]
    # In order to keep bookmarks or any other reference we must update
    # or create the recurring events and not just delete all and create
    return unless changed? and self.recurrence_changed?
  end

  def recurrence
#    attributes[:recurrence] || 
  end

end
