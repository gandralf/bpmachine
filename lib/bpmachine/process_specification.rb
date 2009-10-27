module BPMachine
  module ProcessSpecification
    ::ProcessSpecification = BPMachine::ProcessSpecification
    
    def self.after_processes(&block)
      after_process_actions << block
    end
    
    def self.after_process_actions
      @after_process_actions ||= []
    end
    
    def self.included(klass)
      klass.extend ClassMethods
    end
    
    def change_status(new_status)
      @status = new_status
      self.save
    end
    
    def read_status
      @status
    end
    
    private
    def execute_transitions_from(specification)
      while true
        state = read_status
        transition = specification.transition_for state
        return state if transition.nil?
        return state unless (transition[:if].nil? || self.send(transition[:if]))
        self.send transition[:method]
        change_status transition[:target]
      end
    end
    
    def execute_global_after_actions
      ProcessSpecification.after_process_actions.each do |action|
        action.call(self)
      end
    end
    
    module ClassMethods
      def process(options = {}, &block)
        name = options[:of].to_sym
        specification = transitions_from block
        class_eval do
          define_method(name) do
            state = read_status
            self.send(specification.before_action) unless specification.before_action.nil?
            raise InvalidInitialState, 
              "Process #{name} requires object to have status #{specification.pre_condition}, but it is #{state}" unless specification.applies_to? state
            execute_transitions_from specification
            self.send(specification.after_action) unless specification.after_action.nil?
            execute_global_after_actions
          end
        end
      end
      
      private
      def transitions_from(block)
        specification = SpecificationContext.new
        specification.instance_eval(&block)
        specification
      end
      
      class SpecificationContext
        attr_reader :pre_condition, :before_action, :after_action
        
        def initialize
          @states = {}
        end
        
        def transition_for(state)
          @states[state]
        end
        
        def applies_to?(state)
          return true if @pre_condition.nil?
          @pre_condition == state
        end
        
        private
        def before(action)
          @before_action = action.to_sym
        end
        
        def after(action)
          @after_action = action.to_sym
        end
        
        def must_be(state)
          @pre_condition = state.to_sym
        end
        
        def transition(name, options)
          origin = options[:from].to_sym
          target = options[:to].to_sym
          condition = options[:if].to_sym unless options[:if].nil?
          @states[origin] = { :target => target, :method => name, :if => condition }
        end
      end
    end
  end
end

