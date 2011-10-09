require 'test_helper'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

def setup_db
  ActiveRecord::Schema.define(:version => 1) do
    create_table :people do |t|
      t.string :name
    end
    
    create_table :things do |t|
      t.string :color
    end
    
    create_table :approvals, :force => true do |t|
      t.references :approvable, :polymorphic => true, :null => false
      t.references :approver, :polymorphic => true
      t.boolean :approved, :default => false
      t.timestamps
    end
    add_index :approvals, [:approvable_id, :approvable_type], :unique => true
    
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

class Person < ActiveRecord::Base
end

class Thing < ActiveRecord::Base
  acts_as_approvable
end

class PickyThing < ActiveRecord::Base
  set_table_name 'things'
  acts_as_approvable :constraint => Proc.new { |approver| approver.name == "Admin" }
end


class ActsAsApprovableTest < ActiveSupport::TestCase
  def setup
    setup_db
    
    @person = Person.create! :name => 'Thomas'
    @thing = Thing.create! :color => 'red'
    
    @admin = Person.create! :name => 'Admin'
    @picky_thing = PickyThing.create! :color => 'red'
  end
  
  def teardown
    teardown_db
  end
  
  test "approve a thing by a person" do
    assert_equal true, @thing.pending?
    assert_equal nil, @thing.approver
    
    @thing.approve! @person
    
    assert_equal false, @thing.pending?
    assert_equal @person, @thing.approver
    
    @thing.disapprove!(@person)
    
    assert_equal true, @thing.pending?
    assert_equal @person, @thing.approver
  end
  
  test "approver can be nil" do
    @thing.approve!
    
    assert_equal false, @thing.pending?
    assert_equal nil, @thing.approver
  end
  
  test "disapprove a thing" do
    assert_equal true, @thing.pending?
    assert_equal nil, @thing.approver
    
    @thing.disapprove!(@person)
    
    assert_equal true, @thing.pending?
    #assert_equal @person, @thing.approver
  end

  test "approve a picky thing by a person with restrictions" do
    assert_equal true,  @picky_thing.pending?
    assert_equal nil,   @picky_thing.approver
    
    @picky_thing.approve! @person
    
    assert_equal true,  @picky_thing.pending?
    assert_equal nil,   @picky_thing.approver
    
    @picky_thing.approve! @admin
    
    assert_equal false,  @picky_thing.pending?
    assert_equal @admin,   @picky_thing.approver
  end

end
