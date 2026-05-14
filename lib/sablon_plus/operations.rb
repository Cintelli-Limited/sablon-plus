# -*- coding: utf-8 -*-
module SablonPlus
  module Statement
    class Insertion < Struct.new(:expr, :field)
      def evaluate(env)
        if content = expr.evaluate(env.context)
          field.replace(SablonPlus::Content.wrap(content), env)
        else
          field.remove
        end
      end
    end

    class Loop < Struct.new(:list_expr, :iterator_name, :block)
      def evaluate(env)
        value = list_expr.evaluate(env.context)
        value = value.to_ary if value.respond_to?(:to_ary)
        raise ContextError, "The expression #{list_expr.inspect} should evaluate to an enumerable but was: #{value.inspect}" unless value.is_a?(Enumerable)

        content = value.flat_map do |item|
          iter_env = env.alter_context(iterator_name => item)
          block.process(iter_env)
        end
        update_unique_ids(env, content)
        block.replace(content.reverse)
      end

      private

      # updates all unique id's present in the xml being copied
      def update_unique_ids(env, content)
        doc_xml = env.document.zip_contents[env.document.current_entry]
        dom_entry = env.document[env.document.current_entry]
        #
        # update all docPr tags created
        selector = "//*[local-name() = 'docPr']"
        init_id_val = dom_entry.max_attribute_value(doc_xml, selector, 'id')
        update_tag_attribute(content, 'docPr', 'id', init_id_val)
        #
        # update all cNvPr tags created
        selector = "//*[local-name() = 'cNvPr']"
        init_id_val = dom_entry.max_attribute_value(doc_xml, selector, 'id')
        update_tag_attribute(content, 'cNvPr', 'id', init_id_val)
      end

      # Increments the attribute value of each element with the id by 1
      def update_tag_attribute(content, tag_name, attr_name, init_val)
        content.each do |nodeset|
          nodeset.xpath(".//*[local-name() = '#{tag_name}']").each do |node|
            node[attr_name] = (init_val += 1).to_s
          end
        end
      end
    end

    class Condition
      def initialize(conditions)
        @conditions = conditions
        @else_block = nil
        return unless @conditions.last[:block].start_field.expression =~ /:else/
        #
        # store the else block separately because it is always "true"
        @else_block = @conditions.pop[:block]
      end

      def evaluate(env)
        #
        # process conditional blocks, if and elsif(s)
        any_true = eval_conditional_blocks(env)
        #
        # clear the blocks for any remaining conditions
        @conditions.map { |cond| cond[:block].replace([]) }
        return unless @else_block
        #
        # apply the else clause if none of the conditions were true
        if any_true
          @else_block.replace([])
        elsif @else_block
          @else_block.replace(@else_block.process(env).reverse)
        end
      end

      private

      def eval_conditional_blocks(env)
        #
        # evaluate each expression until a true one is found, false blocks
        # are cleared from the document.
        until @conditions.empty?
          condition = @conditions.shift
          condition_expr = condition[:condition_expr]
          predicate = condition[:predicate]
          block = condition[:block]
          #
          # evaluate the condition - either with a predicate expression or just the value
          value = if predicate
                    # Evaluate the expression to get the object, then call predicate on it
                    obj = condition_expr.evaluate(env.context)
                    evaluate_predicate(predicate, obj, env.context)
                  else
                    condition_expr.evaluate(env.context)
                  end
          #
          if truthy?(value)
            block.replace(block.process(env).reverse)
            break true
          else
            block.replace([])
          end
        end
      end

      def evaluate_predicate(predicate, obj, context)
        # Handle comparison expressions like "client.name == 'Fraser Mayfield'"
        if predicate =~ /(.+?)\s*(==|!=|>|<|>=|<=)\s*(.+)/
          left_expr = $1.strip
          operator = $2
          right_value = $3.strip.gsub(/^['"]|['"]$/, '')  # Remove quotes
          
          # Evaluate the left side expression
          left_val = Expression.parse(left_expr).evaluate(context)
          
          # Perform the comparison
          case operator
          when '==' then left_val.to_s == right_value
          when '!=' then left_val.to_s != right_value
          when '>'  then left_val.to_f > right_value.to_f
          when '<'  then left_val.to_f < right_value.to_f
          when '>=' then left_val.to_f >= right_value.to_f
          when '<=' then left_val.to_f <= right_value.to_f
          else false
          end
        else
          # Handle method call predicates like "empty?"
          # Call the method on the object
          obj.respond_to?(predicate) ? obj.public_send(predicate) : false
        end
      end

      def truthy?(value)
        case value
        when Array
          !value.empty?
        else
          value ? true : false
        end
      end
    end

    class Comment < Struct.new(:block)
      def evaluate(_env)
        block.replace []
      end
    end

    class Image < Struct.new(:image_reference, :block)
      def evaluate(env)
        image = image_reference.evaluate(env.context)
        set_local_rid(env, image) if image
        block.replace(image)
      end

      private

      def set_local_rid(env, image)
        if image.rid_by_file.keys.empty?
          # Only add the image once, it is reused afterwards
          rel_attr = {
            Type: 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image'
          }
          rid = env.document.add_media(image.name, image.data, rel_attr)
          image.rid_by_file[env.document.current_entry] = rid
        elsif image.rid_by_file[env.document.current_entry].nil?
          # locate an existing relationship and duplicate it
          entry = image.rid_by_file.keys.first
          value = image.rid_by_file[entry]
          #
          rel = env.document.find_relationship_by('Id', value, entry)
          rid = env.document.add_relationship(rel.attributes)
          image.rid_by_file[env.document.current_entry] = rid
        end
        #
        image.local_rid = image.rid_by_file[env.document.current_entry]
      end
    end
  end

  module Expression
    class Variable < Struct.new(:name)
      def evaluate(context)
        context[name]
      end

      def inspect
        "«#{name}»"
      end
    end

    class LookupOrMethodCall < Struct.new(:receiver_expr, :expression)
      def evaluate(context)
        if receiver = receiver_expr.evaluate(context)
          expression.split(".").inject(receiver) do |local, m|
            case local
            when Hash
              local[m]
            else
              local.public_send m if local.respond_to?(m)
            end
          end
        end
      end

      def inspect
        "«#{receiver_expr.name}.#{expression}»"
      end
    end

    # Extended parse to support logical and comparison operators
    def self.parse(expression)
      expr = expression.strip
      # Parse logical operators at the top level (lowest precedence)
      depth = 0
      i = 0
      while i < expr.length
        if expr[i] == '(' then depth += 1
        elsif expr[i] == ')' then depth -= 1
        elsif depth == 0
          if expr[i..i+3] == ' and'
            left = expr[0...i].strip
            right = expr[(i+4)..-1].strip
            return Logical.new(parse(left), 'and', parse(right))
          elsif expr[i..i+2] == ' or'
            left = expr[0...i].strip
            right = expr[(i+3)..-1].strip
            return Logical.new(parse(left), 'or', parse(right))
          end
        end
        i += 1
      end
      # Parse comparison operators next
      if expr =~ /(.+?)\s*(==|!=|>=|<=|>|<)\s*(.+)/
        left = parse($1)
        op = $2
        right = parse($3)
        return Comparison.new(left, op, right)
      end
      if expr.include?(".")
        parts = expr.split(".")
        return LookupOrMethodCall.new(Variable.new(parts.shift), parts.join("."))
      end
      if expr =~ /^\d+(\.\d+)?$/
        # Numeric literal
        return NumericLiteral.new(expr.include?(".") ? expr.to_f : expr.to_i)
      end
      if expr =~ /^'.*'|^".*"/
        # String literal
        return StringLiteral.new(expr[1..-2])
      end
      Variable.new(expr)
    end

    class Comparison < Struct.new(:left, :op, :right)
      def evaluate(context)
        l = left.evaluate(context)
        r = right.evaluate(context)
        # Only compare if both are not nil/false and are comparable
        case op
        when '==' then l == r
        when '!=' then l != r
        when '>'  then l.is_a?(Numeric) && r.is_a?(Numeric) ? l > r : false
        when '<'  then l.is_a?(Numeric) && r.is_a?(Numeric) ? l < r : false
        when '>=' then l.is_a?(Numeric) && r.is_a?(Numeric) ? l >= r : false
        when '<=' then l.is_a?(Numeric) && r.is_a?(Numeric) ? l <= r : false
        else false
        end
      end
    end

    class Logical < Struct.new(:left, :op, :right)
      def evaluate(context)
        case op
        when 'and'
          l = left.evaluate(context)
          return false unless l
          r = right.evaluate(context)
          !!(l && r)
        when 'or'
          l = left.evaluate(context)
          return true if l
          r = right.evaluate(context)
          !!(l || r)
        else
          false
        end
      end
    end

    class NumericLiteral < Struct.new(:value)
      def evaluate(_context)
        value
      end
    end

    class StringLiteral < Struct.new(:value)
      def evaluate(_context)
        value
      end
    end
  end
end
