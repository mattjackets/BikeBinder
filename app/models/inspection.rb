module Inspection

  # NOTE: Include the module AFTER the state_machine
  # definition in the class
  def self.included(base)
    machine = base.state_machine
    s = machine.state(:testing)

    machine.state :ready_to_inspect
    machine.state :inspected do
      def process_hash
        self.inspection_hash
      end
      def user_can?(user, action)
        case action
        when :start_inspection
          return user_inspection(user, :valid_only => true).nil?
        when :resume_inspection
          return user_inspection(user, :valid_only => true)
        else
          return true
        end
      end
    end

    machine.on(:do_something) do
      transition :under_repair => :testing
    end

    machine.on :start_inspection do
      transition :ready_to_inspect => :inspected
      transition :inspected => :inspected
    end

    machine.event :resume_inspection do
      transition :inspected => :inspected
    end
  end

  def Inspection.complete?(insp)
    insp && insp.mandatory_questions_complete?    
  end

  # Instance method mixed into a project detail
  def inspection_complete?(insp)
    Inspection.complete?(insp)
  end

  # Inspection is complete and all checks pass
  def Inspection.pass?(insp)
    Inspection.complete?(insp) && insp.correct?
  end

  # Inspection is complete but not all checks pass
  def Inspection.fail?(insp)
    Inspection.complete?(insp) && ! insp.correct?
  end
  
  def valid_inspection?(insp)
    old = old_inspection?(insp)
    return !old
  end

  # When the transition to :inspected state occured
  def inspected_at?
    transitions = self.transitions
    context = transitions[:inspected]

    return context[:origin].created_at unless context[:origin].nil?
    return nil
  end

  # An inspection is old if it was started before the most recent
  # transition to the :inspected state
  def old_inspection?(insp)
    inspected_at = self.inspected_at? if self.inspected?
    return (inspected_at.nil?) ? true : insp.started_at < inspected_at
  end

  def pass_inspection?(insp=nil)
    if insp
      return Inspection.pass?(insp)
    else
      pass = false
      inspections.each do |i|
        pass ||= Inspection.pass?(i)
      end
      return pass
    end
  end

  def fail_inspection?(insp=nil)
    if insp
      return Inspection.fail?(insp)
    else
      # search over collection
      failing = false
      inspections.each do |i|
        failing ||= Inspection.fail?(i)
      end
      return failing
    end
  end
  
  
  # Assumes a 1:1 between user and inspection
  def inspection_hash(inspection=nil, user=nil)
    inspection_access = inspection.access_code if inspection
    inspection_access ||= (user.nil?)?
      self.inspection_access_code :
      user_inspection(user).access_code

    h = {:controller => :surveyor, :action => :edit,
          :survey_code => self.class.inspection_survey_code,
          :response_set_code => inspection_access}
  end
  
  # Get the inspection associated with the given user
  # Specify :valid_only=>true to only return an inspection
  # if it is valid
  def user_inspection(uid=nil, opts={})
    uid ||= uid.id if (uid && uid.respond_to?('id'))
    insp = inspections.where{user_id == uid}.first

    if(opts[:valid_only])
      return insp if self.valid_inspection?(insp)
    else
      return insp
    end

  end

  private


  #extract the user object from the args
  def action_user(transition)
    args = transition.args
    if args
      return args[0][:user]
    else
      return nil
    end
  end

  # Case user has an inspection:
  # Set the inspection hash to correspond to given user
  # User does not have an inspection
  # Start inspection action
  def resume_inspection_action(transition)
    user = action_user(transition)
    
    inspection = user_inspection(user)

    if inspection
      self.inspection_access_code = inspection.access_code
      self.save
    else
      start_inspection_action(transition)
    end
  end

  # TODO inspection on a per-user basis
  def start_inspection_action(transition)
    user = action_user(transition)

    # If an inspection already exists for this user, remove it
    insp = user_inspection(user)
    self.inspections.delete(insp) if insp
    
    #proj.bike.inspection = nil
    #proj.bike.save

    # Find the right survey to use
    @survey = SurveyorUtil.find(self.class::INSPECTION_TITLE)
    
    if @survey
      # Build the response set
      uid ||= user.id if user
      @response_set = ResponseSet.create(:survey => @survey, 
                                       :user_id => uid,
                                       :surveyable_type => self.proj.bike.class.to_s,
                                       :surveyable_id => self.proj.bike.id,
                                       :surveyable_process_type => self.class.to_s,
                                       :surveyable_process_id => self.id)
      if @response_set
        # Assign to this project
        self.inspections << @response_set
        self.inspection_access_code = @response_set.access_code
        self.save
      end
    end

    # Error and stop transition if the inspection can not be made?
  end

end


# Association with bike

# Association with project

# Association with survey

# validate a 1:1 association with a user

# validate that a bike and project can only have 1 inspection for a given user

# pass?

# fail?

# complete?


