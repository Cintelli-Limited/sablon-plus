# -*- coding: utf-8 -*-
require "test_helper"

class ExpressionTest < SablonPlus::TestCase
class ConditionalExpressionTest < SablonPlus::TestCase
  def test_equality_comparison
    expr = SablonPlus::Expression.parse("amount == 500")
    assert expr.evaluate("amount" => 500)
    refute expr.evaluate("amount" => 400)
  end

  def test_inequality_comparison
    expr = SablonPlus::Expression.parse("amount != 500")
    assert expr.evaluate("amount" => 400)
    refute expr.evaluate("amount" => 500)
  end

  def test_greater_than
    expr = SablonPlus::Expression.parse("amount > 500")
    assert expr.evaluate("amount" => 600)
    refute expr.evaluate("amount" => 400)
  end

  def test_less_than
    expr = SablonPlus::Expression.parse("amount < 500")
    assert expr.evaluate("amount" => 400)
    refute expr.evaluate("amount" => 600)
  end

  def test_greater_than_or_equal
    expr = SablonPlus::Expression.parse("amount >= 500")
    assert expr.evaluate("amount" => 500)
    assert expr.evaluate("amount" => 600)
    refute expr.evaluate("amount" => 400)
  end

  def test_less_than_or_equal
    expr = SablonPlus::Expression.parse("amount <= 500")
    assert expr.evaluate("amount" => 500)
    assert expr.evaluate("amount" => 400)
    refute expr.evaluate("amount" => 600)
  end

  def test_string_equality
    expr = SablonPlus::Expression.parse("matter.type == 'Litigation'")
    assert expr.evaluate("matter" => OpenStruct.new(type: "Litigation"))
    refute expr.evaluate("matter" => OpenStruct.new(type: "Other"))
  end

  def test_logical_and
    expr = SablonPlus::Expression.parse("amount > 500 and matter.type == 'Litigation'")
    assert expr.evaluate("amount" => 600, "matter" => OpenStruct.new(type: "Litigation"))
    refute expr.evaluate("amount" => 400, "matter" => OpenStruct.new(type: "Litigation"))
    refute expr.evaluate("amount" => 600, "matter" => OpenStruct.new(type: "Other"))
  end

  def test_logical_or
    expr = SablonPlus::Expression.parse("amount > 500 or matter.type == 'Litigation'")
    assert expr.evaluate("amount" => 600, "matter" => OpenStruct.new(type: "Other"))
    assert expr.evaluate("amount" => 400, "matter" => OpenStruct.new(type: "Litigation"))
    refute expr.evaluate("amount" => 400, "matter" => OpenStruct.new(type: "Other"))
  end
end
end

class VariableExpressionTest < SablonPlus::TestCase
  def test_lookup_the_variable_in_the_context
    expr = SablonPlus::Expression.parse("first_name")
    assert_equal "Jane", expr.evaluate("first_name" => "Jane", "last_name" => "Doe")
  end

  def test_inspect
    expr = SablonPlus::Expression.parse("first_name")
    assert_equal "«first_name»", expr.inspect
  end
end

class LookupOrMethodCallTest < SablonPlus::TestCase
  def test_calls_method_on_object
    user = OpenStruct.new(first_name: "Jack")
    expr = SablonPlus::Expression.parse("user.first_name")
    assert_equal "Jack", expr.evaluate("user" => user)
  end

  def test_calls_perform_lookup_on_hash_with_string_keys
    user = {"first_name" => "Jack"}
    expr = SablonPlus::Expression.parse("user.first_name")
    assert_equal "Jack", expr.evaluate("user" => user)
  end

  def test_inspect
    expr = SablonPlus::Expression.parse("user.first_name")
    assert_equal "«user.first_name»", expr.inspect
  end

  def test_calls_chained_methods
    user = OpenStruct.new(first_name: "Jack", address: OpenStruct.new(line_1: "55A"))
    expr = SablonPlus::Expression.parse("user.address.line_1")
    assert_equal "55A", expr.evaluate("user" => user)
  end

  def test_nested_hash_lookup
    user = {"address" => {"line_1" => "55A"}}
    expr = SablonPlus::Expression.parse("user.address.line_1")
    assert_equal "55A", expr.evaluate("user" => user)
  end

  def test_mix_hash_lookup_and_method_calls
    user = OpenStruct.new(address: {"country" => OpenStruct.new(name: "Switzerland")})
    expr = SablonPlus::Expression.parse("user.address.country.name")
    assert_equal "Switzerland", expr.evaluate("user" => user)
  end

  def test_missing_receiver
    user = OpenStruct.new(first_name: "Jack")
    expr = SablonPlus::Expression.parse("user.address.line_1")
    assert_nil expr.evaluate("user" => user)
    assert_nil expr.evaluate({})
  end
end
