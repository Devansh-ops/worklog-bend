import Base

type Task is Data:
  Task{id: String, private: Bool, count: U32}

def task(id: String, private: Bool, count: U32) -> Task:
  Task{id, private, count}

def keep(text: String) -> String:
  text

def invert(x: Bool) -> Bool:
  match x:
    case True{}:
      False{}
    case False{}:
      True{}

def sum(xs: List<U32>, acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      sum(t, (acc + h : U32))

def wrap(x: U32) -> U32:
  (x + 1 : U32)

def overwrite(xs: Array<U32>) -> Array<U32>:
  Array.set(U32, xs, 0, 9)

type Checked is Data:
  Accepted{value: U32}
  Rejected{reason: String}

def checked(valid: Bool, value: U32) -> Checked:
  match valid:
    case True{}:
      Accepted{value}
    case False{}:
      Rejected{"invalid input"}
