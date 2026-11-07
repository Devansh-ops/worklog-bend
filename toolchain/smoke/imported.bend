import Base
import ./module.bend as M

def via_import(x: U32) -> U32:
  M.identity(x)

law import_identity:
  for x: U32
  {via_import(x) == x : U32}

def import_identity(x):
  {==}
