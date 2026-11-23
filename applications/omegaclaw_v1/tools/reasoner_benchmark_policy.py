"""Independent audit of the offline fixture's executed read/frame operations."""


# Example: native records expose tagged data, never executable policy expressions.
def fields(record):
    return dict(record[1:])


# Example: blocked attempts are not policy violations; unsupported executions remain ungraded.
def check_policy(row):
    observation = row.get('observation')
    if not observation or observation[2][1] != 'Executed':
        return dict(status='ungraded', reason='NoObservedExecution')
    decision = observation[1]
    host = row.get('host_before')
    if not host or decision[3][0] not in ('read-file', 'show-current-frame'):
        return dict(status='ungraded', reason='UnsupportedPolicyAudit')
    bindings = [binding for binding in host[3] if binding[1] == decision[3]]
    if len(bindings) != 1:
        return dict(status='failed', reason='MissingExactBinding')
    accounts = observation[4][4][1]
    if any(account[3] + account[4] > account[2] for account in accounts):
        return dict(status='failed', reason='BudgetOverrun')
    return check_scopes(decision, bindings[0][3], host)


# Example: execution must retain its configured candidate and frame ownership.
def check_scopes(decision, operation, host):
    operation = fields(operation)
    if not handler_requirements(decision[3], operation):
        return dict(status='failed', reason='MissingHandlerRequirements')
    if fields(host[1])['target'] != 'Global' or fields(host[2])['target'] != ['FrameTarget', decision[1][3]]:
        return dict(status='failed', reason='ChangedPolicyOwnership')
    if operation['candidate'] != decision[2] or operation['target'] != decision[1][3]:
        return dict(status='failed', reason='ChangedOwnership')
    checks = [check_scope(fields(scope), operation, host[4][1]) for scope in host[1:3]]
    failures = [reason for status, reason in checks if status == 'failed']
    unknown = [reason for status, reason in checks if status == 'ungraded']
    if failures:
        return dict(status='failed', reason=failures[0])
    return dict(status='ungraded', reason=unknown[0]) if unknown else dict(status='passed', reason='ObservedPolicySatisfied')


# Example: a binding cannot weaken the known handler's mandatory permissions or command charge.
def handler_requirements(command, operation):
    required = ['files.read', 'files.read:' + command[1]] if command[0] == 'read-file' else ['frames.read']
    charges = [cost[3] for cost in operation['costs'] if cost[1:3] == ['commands', 'units']]
    return (operation['skill'] == command[0] and set(required) <= set(operation['permissions'])
            and len(charges) == 1 and charges[0] >= 1)


# Example: skills, permissions, egress, budgets and known constraints are checked independently.
def check_scope(scope, operation, accounts):
    if operation['skill'] not in scope['skills']:
        return 'failed', 'SkillDenied'
    for name in ('permissions', 'egress'):
        if not set(operation[name]) <= set(scope[name]):
            return 'failed', name + 'Denied'
    if not budget_allows(scope['target'], operation['costs'], accounts):
        return 'failed', 'BudgetExceeded'
    checks = [constraint_allows(rule, operation, scope) for rule in scope['constraints']]
    if False in checks:
        return 'failed', 'ConstraintViolated'
    return ('ungraded', 'UnsupportedConstraint') if None in checks else ('passed', 'Allowed')


# Example: spent and reserved units are unavailable before this cycle's admission.
def budget_allows(target, costs, accounts):
    for _, resource, unit, amount in costs:
        matches = [row for row in accounts if row[1][2:] == [target, resource, unit]]
        if len(matches) != 1:
            return False
        account = matches[0]
        if account[5] != 'Open' or amount > account[2] - account[3] - account[4]:
            return False
    return True


# Example: unknown constraints cannot be silently treated as satisfied.
def constraint_allows(rule, operation, scope):
    kind, *values = rule
    if kind == 'DenySkill':
        return operation['skill'] != values[0]
    if kind == 'RequirePermission':
        return values[0] in scope['permissions']
    if kind == 'DenyEgress':
        return values[0] not in operation['egress']
    if kind == 'MaxCost':
        costs = [cost for cost in operation['costs'] if cost[1] == values[0]]
        return all(cost[2] == values[1] for cost in costs) and sum(cost[3] for cost in costs) <= values[2]
    return None
