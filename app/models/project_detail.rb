# Include this module in each project detail that
# defines a state machine
module ProjectDetailStates
  def self.included(base)
    machine = base.state_machine

    # Required transition to done state
    # Must be the last transition in order for done to be
    # lowest priority in states list
    machine.event :finish_project do
      last_step = machine.states.by_priority[-2]
      transition last_step.name => :done, :if => :pass_req?
    end

    # Check projects to ensure they are open
    machine.before_transition :do => :proj_must_be_open
    # Force projects to close on finish action
    # machine.after_transition (machine.any-:done) => :done, :do => "proj.close"

    machine.state :done do
      def process_hash
        # transition to the finish page
        h = {:controller => :projects,
          :id => self.proj,
          :action => :finish}
      end
    end

  end
end

class ProjectDetail < ActiveRecord::Base

  # For table name prefixing see:
  # http://stackoverflow.com/questions/8911046/rails-table-name-prefix-missing
  self.abstract_class = true
  self.table_name_prefix = "project_"

  belongs_to :proj, :polymorphic => :true, :dependent => :destroy

  has_paper_trail :class_name => 'ProjectDetailVersion',
                  :meta => {:state => Proc.new{|detail| detail.state}}

  attr_accessible nil

  state_machine :initial=>:done do
    state :done
  end

  def pass_req?
    nil
  end

  include Inspection

  def initial_state
    if @init_state
      return @init_state
    end

    states = self.class.state_machine.states
    states.each do |s|
      if s.initial?
        @init_state = s.name
        return @init_state
      end
    end
  end

  def completion_steps
    if @steps.nil? && !self.proj.terminal?

      obj = self.class.new
      states = obj.state_paths(:guard=>false).from_states
      
      @steps = states
      @steps << :done

      return @steps
    end
    return @steps
  end

  # For every step, fetch the version that
  # the previous and next steps were
  # transitioned from and to, respectively.
  def transitions()
    steps = completion_steps

    retval = {}
    vref = self.versions.last

    steps.each do |sname|
      retval[sname.to_sym] = vref.transition_context(sname)
    end

    retval
  end

  # validate if a user can perform a given action
  def user_can?(user, action)
    true
  end

  # method definition to allow superclass call
  # as needed by state machine
  def process_hash
    nil
  end

  def work_log
    nil
  end

  # Make sure that only one detail record is made for a given project
  validates_uniqueness_of :proj_id, :allow_nil => :false

  private
  
  def proj_must_be_open(transition)
    proj_detail = transition.object

    if proj_detail.proj.open?
      true
    else
      proj_detail.errors.add(:action_unallowed, "Project is closed")
      throw :halt
      false
    end
  end



end
