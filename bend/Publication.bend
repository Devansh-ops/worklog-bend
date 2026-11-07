import Base
import ./Core.bend as Core

# Host codecs supply the canonical lossless encoding of the complete immutable
# write plan, including destination, branch, base/tree, contents/deletions,
# message and acknowledged event identities. Equality covers all of those bytes.
def schemas_compatible(schemas: List<&2, U32>) -> Bool:
  match schemas:
    case Nil{}:
      True{}
    case Con{schema, rest}:
      Bool.and(Core.schema_allowed(schema), schemas_compatible(rest))

def approved(schemas: List<&2, U32>, approved_plan: String, execution_plan: String) -> Bool:
  Bool.and(schemas_compatible(schemas), String.eq(approved_plan, execution_plan))


