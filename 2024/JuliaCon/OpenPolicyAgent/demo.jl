using OpenPolicyAgent
using OpenAPI

import OpenPolicyAgent: ASTWalker
import OpenPolicyAgent.ASTWalker.AST: ASTVisitor
import OpenPolicyAgent.ASTWalker.SQL: SQLVisitor, UnconditionalInclude, UnconditionalExclude

const policy = """
    package accounting_system

    # no one is allowed by default
    default allow = false
    default check_business_hours = false

    check_business_hours {
        input.hourofday >= 9
        input.hourofday <= 17
        input.dayofweek >= 1
        input.dayofweek <= 5
    }

    # all users during business hours when audit is not happening
    allow {
        input.is_audit_time == false
        input.is_logged_in == true
        check_business_hours
    }

    # boss at all hours when audit is not happening
    allow {
        input.is_audit_time == false
        input.is_logged_in == true
        input.user.role == "boss"
    }

    # only auditors during business hours when audit is happening
    allow {
        input.is_audit_time == true
        input.is_logged_in == true
        input.user.role == "auditor"
        check_business_hours
    }
"""


# Start the OPA server
opa_server = OpenPolicyAgent.Server.MonitoredOPAServer("demo_config.yaml")
OpenPolicyAgent.Server.start!(opa_server)


# Create client to interact with the OPA server
openapi_client = OpenAPI.Clients.Client("http://localhost:8181"; escape_path_params=false)
policy_client = OpenPolicyAgent.Client.PolicyApi(openapi_client)
compile_client = OpenPolicyAgent.Client.CompileApi(openapi_client)


# Initialize the server by loading the policy
response, _ = OpenPolicyAgent.Client.put_policy_module(policy_client, "accounting_system", policy)
@assert isa(response, OpenPolicyAgent.Client.PutPolicySuccessResponse)


function is_allowed(input)
    query = "data.accounting_system.allow == true"
    unknowns = haskey(input, "user") ? [] : ["input.user"]
    partial_query_schema = OpenPolicyAgent.Client.PartialQuerySchema(;
        query = query,
        input = input,
        unknowns = unknowns,
    )

    # compile the query by partially evaluating it
    response, _ = OpenPolicyAgent.Client.post_compile(
        compile_client;
        partial_query_schema = partial_query_schema,
    )
    @assert isa(response, OpenPolicyAgent.Client.CompileSuccessResponse)

    # translate resultant AST to SQL
    result = response.result
    ast = ASTWalker.walk(ASTVisitor(), result)
    sqlvisitor = SQLVisitor(Dict{String, String}(), Dict{String, String}())
    sqlcondition = ASTWalker.walk(sqlvisitor, ast)

    return isa(sqlcondition, UnconditionalExclude) ? "false" :
           isa(sqlcondition, UnconditionalInclude) ? "true" :
           sqlcondition.sql
end


# users are allowed during business hours, when there's no audit
@assert "true" == is_allowed(Dict(
        "hourofday" => 10,
        "dayofweek" => 2,
        "is_audit_time" => false,
        "is_logged_in" => true,
        "user" => Dict("role" => "user")
    )
)


# users are not allowed outside business hours
@assert "false" == is_allowed(Dict(
        "hourofday" => 1,
        "dayofweek" => 2,
        "is_audit_time" => false,
        "is_logged_in" => true,
        "user" => Dict("role" => "user")
    )
)


# boss is allowed at all hours, when there's no audit
@assert "true" == is_allowed(Dict(
        "hourofday" => 1,
        "dayofweek" => 2,
        "is_audit_time" => false,
        "is_logged_in" => true,
        "user" => Dict("role" => "boss")
    )
)


# even boss is not allowed when there's an audit
@assert "false" == is_allowed(Dict(
        "hourofday" => 10,
        "dayofweek" => 2,
        "is_audit_time" => true,
        "is_logged_in" => true,
        "user" => Dict("role" => "boss")
    )
)


# find the list of users who are allowed access during audit
is_allowed(Dict(
        "hourofday" => 10,
        "dayofweek" => 2,
        "is_audit_time" => true,
        "is_logged_in" => true,
    )
)


# find list of users who are allowed access outside business hours
is_allowed(Dict(
        "hourofday" => 1,
        "dayofweek" => 2,
        "is_audit_time" => false,
        "is_logged_in" => true,
    )
)


OpenPolicyAgent.Server.stop!(opa_server)

