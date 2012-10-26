require 'rubygems'
require 'active_record'
require 'logger'
require 'spec_helper'

load_schema

# if you want to see the statements while running the spec enable the following line
# ActiveRecord::Base.logger = Logger.new(STDERR)

shared_examples_for "aasm model" do
  it "should include persistence mixins" do
    @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence)
    @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::InstanceMethods)
  end
end

describe "class methods for classes without own read or write state" do
  before(:each) do
    @klass = Gate
  end
  it_should_behave_like "aasm model"
  it "should include all persistence mixins" do
    @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::ReadState)
    @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::WriteState)
    @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::WriteStateWithoutPersistence)
  end
end

describe "class methods for classes with own read state" do
  before(:each) do
    @klass = Reader
  end
  it_should_behave_like "aasm model"
  it "should include all persistence mixins but read state" do
    @klass.included_modules.should_not be_include(AASM::Persistence::ActiveRecordPersistence::ReadState)
    @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::WriteState)
    @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::WriteStateWithoutPersistence)
  end
end

describe "class methods for classes with own write state" do
  before(:each) do
    @klass = Writer
  end
  it_should_behave_like "aasm model"
  it "should include include all persistence mixins but write state" do
    @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::ReadState)
    @klass.included_modules.should_not be_include(AASM::Persistence::ActiveRecordPersistence::WriteState)
    @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::WriteStateWithoutPersistence)
  end
end

describe "class methods for classes without persistence" do
  before(:each) do
    @klass = Transient
  end
  it_should_behave_like "aasm model"
  it "should include all mixins but persistence" do
    @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::ReadState)
    @klass.included_modules.should be_include(AASM::Persistence::ActiveRecordPersistence::WriteState)
    @klass.included_modules.should_not be_include(AASM::Persistence::ActiveRecordPersistence::WriteStateWithoutPersistence)
  end
end

describe "instance methods" do
  before do
    @gate = Gate.new
  end

  it "should respond to aasm states" do
    @gate.should respond_to(:aasm_read_state)
    @gate.should respond_to(:aasm_write_state)
    @gate.should respond_to(:aasm_write_state_without_persistence)
  end

  it "should return the initial state when new and the aasm field is nil" do
    @gate.aasm_current_state.should == :opened
  end

  it "should return the aasm column when new and the aasm field is not nil" do
    @gate.aasm_state = "closed"
    @gate.aasm_current_state.should == :closed
  end

  it "should return the aasm column when not new and the aasm_column is not nil" do
    @gate.stub!(:new_record?).and_return(false)
    @gate.aasm_state = "state"
    @gate.aasm_current_state.should == :state
  end

  it "should allow a nil state" do
    @gate.stub!(:new_record?).and_return(false)
    @gate.aasm_state = nil
    @gate.aasm_current_state.should be_nil
  end

  it "should have aasm_ensure_initial_state" do
    @gate.send :aasm_ensure_initial_state
  end

  it "should call aasm_ensure_initial_state on validation before create" do
    @gate.should_receive(:aasm_ensure_initial_state).and_return(true)
    @gate.valid?
  end

  it "should call aasm_ensure_initial_state on validation before create" do
    @gate.stub!(:new_record?).and_return(false)
    @gate.should_not_receive(:aasm_ensure_initial_state)
    @gate.valid?
  end

end

describe 'subclasses' do
  it "should have the same states as its parent class" do
    Derivate.aasm_states.should == Simple.aasm_states
  end

  it "should have the same events as its parent class" do
    Derivate.aasm_events.should == Simple.aasm_events
  end

  it "should have the same column as its parent class" do
    Derivate.aasm_column.should == :status
  end

  it "should have the same column as its parent even for the new dsl" do
    SimpleNewDsl.aasm_column.should == :status
    DerivateNewDsl.aasm_column.should == :status
  end
end

describe "named scopes with the old DSL" do

  context "Does not already respond_to? the scope name" do
    it "should add a scope" do
      Simple.should respond_to(:unknown_scope)
      Simple.unknown_scope.class.should == ActiveRecord::Relation
    end
  end

  context "Already respond_to? the scope name" do
    it "should not add a scope" do
      Simple.should respond_to(:new)
      Simple.new.class.should == Simple
    end
  end

end

describe "named scopes with the new DSL" do

  context "Does not already respond_to? the scope name" do
    it "should add a scope" do
      SimpleNewDsl.should respond_to(:unknown_scope)
      SimpleNewDsl.unknown_scope.class.should == ActiveRecord::Relation
    end
  end

  context "Already respond_to? the scope name" do
    it "should not add a scope" do
      SimpleNewDsl.should respond_to(:new)
      SimpleNewDsl.new.class.should == SimpleNewDsl
    end
  end

end

describe 'initial states' do

  it 'should support conditions' do
    Thief.new(:skilled => true).aasm_current_state.should == :rich
    Thief.new(:skilled => false).aasm_current_state.should == :jailed
  end
end

describe 'transitions with persistence' do

  it 'should not store states for invalid models' do
    validator = Validator.create(:name => 'name')
    validator.should be_valid
    validator.should be_sleeping

    validator.name = nil
    validator.should_not be_valid
    validator.run!.should be_false
    validator.should be_sleeping

    validator.reload
    validator.should_not be_running
    validator.should be_sleeping

    validator.name = 'another name'
    validator.should be_valid
    validator.run!.should be_true
    validator.should be_running

    validator.reload
    validator.should be_running
    validator.should_not be_sleeping
  end

  it 'should store states for invalid models if configured' do
    persistor = InvalidPersistor.create(:name => 'name')
    persistor.should be_valid
    persistor.should be_sleeping

    persistor.name = nil
    persistor.should_not be_valid
    persistor.run!.should be_true
    persistor.should be_running

    persistor = InvalidPersistor.find(persistor.id)
    persistor.valid?
    persistor.should be_valid
    persistor.should be_running
    persistor.should_not be_sleeping

    persistor.reload
    persistor.should be_running
    persistor.should_not be_sleeping
  end

  describe 'transactions' do
    it 'should rollback all changes' do
      worker = Worker.create!(:name => 'worker', :status => 'sleeping')
      transactor = Transactor.create!(:name => 'transactor', :worker => worker)
      transactor.should be_sleeping
      worker.status.should == 'sleeping'

      lambda {transactor.run!}.should raise_error(StandardError, 'failed on purpose')
      transactor.should be_running
      worker.reload.status.should == 'sleeping'
    end
  end

end