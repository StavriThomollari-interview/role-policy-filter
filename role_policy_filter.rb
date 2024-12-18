
# Created By <stavrithomollari@outlook.com>
# Created Date: 2021-09-16 16:55:58 +0200

class RolePolicyFilter

  CLIENT_ROLE = 'client'.freeze
  ADMIN_ROLE = 'admin'.freeze
  TRUE_VALUE = 'TRUE'.freeze
  DENY_EFFECT = 'deny'.freeze

  def initialize(model_name, permissions, custom_conditions = {}, user_role = 'client')
    @policies = permissions[model_name].presence || []
    @resource_model = model_name.constantize 
    @custom_conditions = custom_conditions
    @user_role = user_role
  end

  def run
    return @resource_model.none if no_policies_for_client?

    @resource_model
      .where(where_conditions)
      .where(@custom_conditions)
  end

  private
  
  def no_policies_for_client?
    @policies.blank? && client?
  end

  def client?
    @user_role == CLIENT_ROLE
  end

  def admin?
    @user_role == ADMIN_ROLE
  end

  def where_conditions
    # Admin can see all resources so we can skip conditions.
    return {} if admin?
 
    queries = @policies.map { |policy| build_condition(policy) }
    
    # TODO: The logic here needs to be refactored
    queries.reject! { |query| query == Arel.sql(TRUE_VALUE) } # Reject 'TRUE' condition
    queries.reduce(:or)
  end

  def build_condition(policy)
    conditions = policy['conditions'].map do |condition_column, condition_predicate, condition_value|
      build_condition_for_column(condition_column, condition_predicate, condition_value)
    end

    return Arel.sql('TRUE') if conditions.blank?

    result = @resource_model.arel_table.grouping(conditions.reduce(:and))

    # If effect is deny then we negate all condition by using NOT.
    apply_effect(result, policy['effect'])
  end
  
  def build_condition_for_column(condition_column, condition_predicate, condition_value)
    parsed_value = parse_condition_value(condition_predicate, condition_value)

    if parsed_value.is_a? Date
      casted_column(condition_column).public_send(condition_predicate, parsed_value)
    else
      @resource_model.arel_table[condition_column].public_send(condition_predicate, parsed_value)
    end
  end

  def casted_column(condition_column)
    Arel::Nodes::NamedFunction.new('CAST', [@resource_model.arel_table[condition_column].as('DATE')])
  end

  def parse_condition_value(condition_predicate, condition_value)
    case condition_predicate
    when 'in', 'not_in', 'eq_any'
      parse_array_value(condition_value)
    else
      condition_value
    end
  end

  def parse_array_value(value)
    return value if value.is_a?(Array)

    value.split(/[;,]+/).map(&:strip) if value.present?
  rescue StandardError
    nil
  end

  def apply_effect(result, effect)
    effect.to_s == DENY_EFFECT ? Arel::Nodes::Not.new(result) : result
  end
end
