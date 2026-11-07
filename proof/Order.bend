import Base

def false_true_type(value: Bool) -> Type:
  match value:
    case False{}:
      Empty
    case True{}:
      Unit

def false_not_true(equality: {False{} == True{} : Bool}) -> Empty:
  %Equal.sym(Bool, False{}, True{}, equality) : false_true_type(_)
  Unit{}

def cmp_equal(a: Cmp, b: Cmp) -> Bool:
  match a b:
    case LT{} LT{}:
      True{}
    case EQ{} EQ{}:
      True{}
    case GT{} GT{}:
      True{}
    case _ _:
      False{}

# The transitive comparator table records every constrained same-direction case.
# Opposite strict directions deliberately impose no conclusion.
def chain(a: Cmp, b: Cmp, c: Cmp) -> Bool:
  match a b:
    case EQ{} o:
      cmp_equal(o, c)
    case o EQ{}:
      cmp_equal(o, c)
    case LT{} LT{}:
      cmp_equal(LT{}, c)
    case GT{} GT{}:
      cmp_equal(GT{}, c)
    case _ _:
      True{}

def compose(first: Cmp, second: Cmp) -> Cmp:
  match first:
    case EQ{}:
      second
    case other:
      other

def reverse(order: Cmp) -> Cmp:
  match order:
    case LT{}:
      GT{}
    case EQ{}:
      EQ{}
    case GT{}:
      LT{}




# Reviewed comparator reflection support, copied without importing root laws.
def false_true_discriminator(value: Bool) -> Type:
  match value:
    case False{}:
      Empty
    case True{}:
      Unit

law word_order_reflexive:
  for n: Nat
  for w: Word(n)
  {Word.cmp(n, w, w) == EQ{} : Cmp}

law u32_order_reflexive:
  for x: U32
  {U32.cmp(x, x) == EQ{} : Cmp}

law string_order_reflexive:
  for s: String
  {String.order(s, s) == EQ{} : Cmp}

law string_equality_reflexive:
  for s: String
  {String.eq(s, s) == True{} : Bool}

law false_is_not_true:
  for contradiction: {False{} == True{} : Bool}
  Empty

law bool_order_equality_sound:
  for a: Bool
  for b: Bool
  for equality: {Bool.cmp(a, b) == EQ{} : Cmp}
  {a == b : Bool}

law word_cmp_fin_tail:
  for a: Bool
  for b: Bool
  for tail: Cmp
  for equality: {Word.cmp.fin(a, b, tail) == EQ{} : Cmp}
  {tail == EQ{} : Cmp}

law word_cmp_fin_head:
  for a: Bool
  for b: Bool
  for tail: Cmp
  for tail_equal: {tail == EQ{} : Cmp}
  for equality: {Word.cmp.fin(a, b, tail) == EQ{} : Cmp}
  {Bool.cmp(a, b) == EQ{} : Cmp}

law word_order_equality_sound:
  for n: Nat
  for a: Word(n)
  for b: Word(n)
  for +equality: {Word.cmp(n, a, b) == EQ{} : Cmp}
  {a == b : Word(n)}

law u32_order_equality_sound:
  for a: U32
  for b: U32
  for equality: {U32.cmp(a, b) == EQ{} : Cmp}
  {a == b : U32}

law string_order_go_lt:
  for a: String
  for b: String
  {String.order.go(a, b, LT{}) == LT{} : Cmp}

law string_order_go_gt:
  for a: String
  for b: String
  {String.order.go(a, b, GT{}) == GT{} : Cmp}

law string_order_go_eq_premise:
  for a: String
  for b: String
  for order: Cmp
  for equality: {String.order.go(a, b, order) == EQ{} : Cmp}
  {order == EQ{} : Cmp}

law string_order_equality_sound:
  for a: String
  for b: String
  for +equality: {String.order(a, b) == EQ{} : Cmp}
  {a == b : String}

law cmp_is_eq_sound:
  for order: Cmp
  for equality: {Cmp.is_eq(order) == True{} : Bool}
  {order == EQ{} : Cmp}

law string_equality_sound:
  for +a: String
  for +b: String
  for equality: {String.eq(a, b) == True{} : Bool}
  {a == b : String}

def word_order_reflexive(n, w):
  match n:
    case 0n:
      {==}
    case 1n+p:
      match w:
        case WCon{b, t}:
          match b:
            case False{}:
              Equal.cong(Cmp, Cmp, c => Word.cmp.fin(False{}, False{}, c),
                Word.cmp(p, t, t), EQ{}, word_order_reflexive(p, t))
            case True{}:
              Equal.cong(Cmp, Cmp, c => Word.cmp.fin(True{}, True{}, c),
                Word.cmp(p, t, t), EQ{}, word_order_reflexive(p, t))

def u32_order_reflexive(x):
  match x:
    case U32{w}:
      word_order_reflexive(32n, w)

def string_order_reflexive(s):
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{x}, t}:
      Equal.trans(Cmp, String.order.go(t, t, U32.cmp(x, x)), String.order(t, t), EQ{},
        Equal.cong(Cmp, Cmp, c => String.order.go(t, t, c),
          U32.cmp(x, x), EQ{}, u32_order_reflexive(x)),
        string_order_reflexive(t))

def string_equality_reflexive(s):
  Equal.cong(Cmp, Bool, c => Cmp.is_eq(c),
    String.order(s, s), EQ{}, string_order_reflexive(s))

def false_is_not_true(contradiction):
  %Equal.sym(Bool, False{}, True{}, contradiction) : false_true_discriminator(_)
  Unit{}

def bool_order_equality_sound(a, b, equality):
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      Equal.cong(Cmp, Bool, c => Cmp.is_eq(c), LT{}, EQ{}, equality)
    case True{} False{}:
      Equal.sym(Bool, False{}, True{}, Equal.cong(Cmp, Bool, c => Cmp.is_eq(c), GT{}, EQ{}, equality))
    case True{} True{}:
      {==}

def word_cmp_fin_tail(a, b, tail, equality):
  match tail:
    case LT{}:
      equality
    case EQ{}:
      {==}
    case GT{}:
      equality

def word_cmp_fin_head(a, b, tail, tail_equal, equality):
  Equal.trans(Cmp, Bool.cmp(a, b), Word.cmp.fin(a, b, tail), EQ{},
    Equal.sym(Cmp, Word.cmp.fin(a, b, tail), Bool.cmp(a, b),
      Equal.cong(Cmp, Cmp, c => Word.cmp.fin(a, b, c), tail, EQ{}, tail_equal)),
    equality)

def word_order_equality_sound(n, a, b, equality):
  match n:
    case 0n:
      match a b:
        case WNil{} WNil{}:
          {==}
    case Succ{+p}:
      match a b:
        case WCon{+ah, +at} WCon{+bh, +bt}:
          +tail_order = word_cmp_fin_tail(ah, bh, Word.cmp(p, at, bt), equality)
          head_order = word_cmp_fin_head(ah, bh, Word.cmp(p, at, bt), tail_order, equality)
          head_equal = bool_order_equality_sound(ah, bh, head_order)
          tail_equal = word_order_equality_sound(p, at, bt, tail_order)
          Equal.trans(Word(1n+p), WCon{ah, at}, WCon{bh, at}, WCon{bh, bt},
            Equal.cong(Bool, Word(1n+p), bit => WCon{bit, at}, ah, bh, head_equal),
            Equal.cong(Word(p), Word(1n+p), bits => WCon{bh, bits}, at, bt, tail_equal))

def u32_order_equality_sound(a, b, equality):
  match a b:
    case U32{x} U32{y}:
      Equal.cong(Word(32n), U32, bits => U32{bits}, x, y,
        word_order_equality_sound(32n, x, y, equality))

def string_order_go_lt(a, b):
  match a b:
    case SNil{} SNil{}:
      {==}
    case SNil{} SCon{h, t}:
      {==}
    case SCon{h, t} SNil{}:
      {==}
    case SCon{Chr{x}, at} SCon{Chr{y}, bt}:
      {==}

def string_order_go_gt(a, b):
  match a b:
    case SNil{} SNil{}:
      {==}
    case SNil{} SCon{h, t}:
      {==}
    case SCon{h, t} SNil{}:
      {==}
    case SCon{Chr{x}, at} SCon{Chr{y}, bt}:
      {==}

def string_order_go_eq_premise(a, b, order, equality):
  match order:
    case LT{}:
      Equal.trans(Cmp, LT{}, String.order.go(a, b, LT{}), EQ{},
        Equal.sym(Cmp, String.order.go(a, b, LT{}), LT{}, string_order_go_lt(a, b)), equality)
    case EQ{}:
      {==}
    case GT{}:
      Equal.trans(Cmp, GT{}, String.order.go(a, b, GT{}), EQ{},
        Equal.sym(Cmp, String.order.go(a, b, GT{}), GT{}, string_order_go_gt(a, b)), equality)

def string_order_equality_sound(a, b, equality):
  match a b:
    case SNil{} SNil{}:
      {==}
    case SNil{} SCon{h, t}:
      Empty.absurd({SNil{} == SCon{h, t} : String},
        false_is_not_true(Equal.cong(Cmp, Bool, c => Cmp.is_eq(c), LT{}, EQ{}, equality)))
    case SCon{h, t} SNil{}:
      Empty.absurd({SCon{h, t} == SNil{} : String},
        false_is_not_true(Equal.cong(Cmp, Bool, c => Cmp.is_eq(c), GT{}, EQ{}, equality)))
    case SCon{Chr{+x}, +at} SCon{Chr{+y}, +bt}:
      +head_order = string_order_go_eq_premise(at, bt, U32.cmp(x, y), equality)
      head_equal = u32_order_equality_sound(x, y, head_order)
      tail_order = Equal.trans(Cmp, String.order(at, bt), String.order.go(at, bt, U32.cmp(x, y)), EQ{},
        Equal.sym(Cmp, String.order.go(at, bt, U32.cmp(x, y)), String.order(at, bt),
          Equal.cong(Cmp, Cmp, c => String.order.go(at, bt, c), U32.cmp(x, y), EQ{}, head_order)), equality)
      tail_equal = string_order_equality_sound(at, bt, tail_order)
      Equal.trans(String, SCon{Chr{x}, at}, SCon{Chr{y}, at}, SCon{Chr{y}, bt},
        Equal.cong(U32, String, code => SCon{Chr{code}, at}, x, y, head_equal),
        Equal.cong(String, String, tail => SCon{Chr{y}, tail}, at, bt, tail_equal))

def cmp_is_eq_sound(order, equality):
  match order:
    case LT{}:
      Empty.absurd({LT{} == EQ{} : Cmp}, false_is_not_true(equality))
    case EQ{}:
      {==}
    case GT{}:
      Empty.absurd({GT{} == EQ{} : Cmp}, false_is_not_true(equality))

def string_equality_sound(a, b, equality):
  string_order_equality_sound(a, b,
    cmp_is_eq_sound(String.order(a, b), equality))


def compose_chain(+a: Cmp, +b: Cmp, +c: Cmp, +x: Cmp, +y: Cmp, +z: Cmp,
  primary: {chain(a, b, c) == True{} : Bool}, secondary: {chain(x, y, z) == True{} : Bool}) ->
  {chain(compose(a, x), compose(b, y), compose(c, z)) == True{} : Bool}:
  match a b c:
    case LT{} LT{} LT{}:
      {==}
    case LT{} LT{} EQ{}:
      Empty.absurd({chain(compose(LT{}, x), compose(LT{}, y), compose(EQ{}, z)) == True{} : Bool}, false_not_true(primary))
    case LT{} LT{} GT{}:
      Empty.absurd({chain(compose(LT{}, x), compose(LT{}, y), compose(GT{}, z)) == True{} : Bool}, false_not_true(primary))
    case LT{} EQ{} LT{}:
      match y:
        case LT{}:
          {==}
        case EQ{}:
          {==}
        case GT{}:
          {==}
    case LT{} EQ{} EQ{}:
      Empty.absurd({chain(compose(LT{}, x), compose(EQ{}, y), compose(EQ{}, z)) == True{} : Bool}, false_not_true(primary))
    case LT{} EQ{} GT{}:
      Empty.absurd({chain(compose(LT{}, x), compose(EQ{}, y), compose(GT{}, z)) == True{} : Bool}, false_not_true(primary))
    case LT{} GT{} LT{}:
      {==}
    case LT{} GT{} EQ{}:
      {==}
    case LT{} GT{} GT{}:
      {==}
    case EQ{} LT{} LT{}:
      match x:
        case LT{}:
          {==}
        case EQ{}:
          {==}
        case GT{}:
          {==}
    case EQ{} LT{} EQ{}:
      Empty.absurd({chain(compose(EQ{}, x), compose(LT{}, y), compose(EQ{}, z)) == True{} : Bool}, false_not_true(primary))
    case EQ{} LT{} GT{}:
      Empty.absurd({chain(compose(EQ{}, x), compose(LT{}, y), compose(GT{}, z)) == True{} : Bool}, false_not_true(primary))
    case EQ{} EQ{} LT{}:
      Empty.absurd({chain(compose(EQ{}, x), compose(EQ{}, y), compose(LT{}, z)) == True{} : Bool}, false_not_true(primary))
    case EQ{} EQ{} EQ{}:
      secondary
    case EQ{} EQ{} GT{}:
      Empty.absurd({chain(compose(EQ{}, x), compose(EQ{}, y), compose(GT{}, z)) == True{} : Bool}, false_not_true(primary))
    case EQ{} GT{} LT{}:
      Empty.absurd({chain(compose(EQ{}, x), compose(GT{}, y), compose(LT{}, z)) == True{} : Bool}, false_not_true(primary))
    case EQ{} GT{} EQ{}:
      Empty.absurd({chain(compose(EQ{}, x), compose(GT{}, y), compose(EQ{}, z)) == True{} : Bool}, false_not_true(primary))
    case EQ{} GT{} GT{}:
      match x:
        case LT{}:
          {==}
        case EQ{}:
          {==}
        case GT{}:
          {==}
    case GT{} LT{} LT{}:
      {==}
    case GT{} LT{} EQ{}:
      {==}
    case GT{} LT{} GT{}:
      {==}
    case GT{} EQ{} LT{}:
      Empty.absurd({chain(compose(GT{}, x), compose(EQ{}, y), compose(LT{}, z)) == True{} : Bool}, false_not_true(primary))
    case GT{} EQ{} EQ{}:
      Empty.absurd({chain(compose(GT{}, x), compose(EQ{}, y), compose(EQ{}, z)) == True{} : Bool}, false_not_true(primary))
    case GT{} EQ{} GT{}:
      match y:
        case LT{}:
          {==}
        case EQ{}:
          {==}
        case GT{}:
          {==}
    case GT{} GT{} LT{}:
      Empty.absurd({chain(compose(GT{}, x), compose(GT{}, y), compose(LT{}, z)) == True{} : Bool}, false_not_true(primary))
    case GT{} GT{} EQ{}:
      Empty.absurd({chain(compose(GT{}, x), compose(GT{}, y), compose(EQ{}, z)) == True{} : Bool}, false_not_true(primary))
    case GT{} GT{} GT{}:
      {==}

def bool_chain(+a: Bool, +b: Bool, +c: Bool) -> {chain(Bool.cmp(a, b), Bool.cmp(b, c), Bool.cmp(a, c)) == True{} : Bool}:
  match a b c:
    case False{} False{} False{}:
      {==}
    case False{} False{} True{}:
      {==}
    case False{} True{} False{}:
      {==}
    case False{} True{} True{}:
      {==}
    case True{} False{} False{}:
      {==}
    case True{} False{} True{}:
      {==}
    case True{} True{} False{}:
      {==}
    case True{} True{} True{}:
      {==}

def chain_cong(+a: Cmp, +b: Cmp, +c: Cmp, +x: Cmp, +y: Cmp, +z: Cmp,
  ax: {a == x : Cmp}, by: {b == y : Cmp}, cz: {c == z : Cmp}) -> {chain(a, b, c) == chain(x, y, z) : Bool}:
  Equal.trans(Bool, chain(a, b, c), chain(x, b, c), chain(x, y, z),
    Equal.cong(Cmp, Bool, p => chain(p, b, c), a, x, ax),
    Equal.trans(Bool, chain(x, b, c), chain(x, y, c), chain(x, y, z),
      Equal.cong(Cmp, Bool, p => chain(x, p, c), b, y, by),
      Equal.cong(Cmp, Bool, p => chain(x, y, p), c, z, cz)))

def fin_compose(+a: Bool, +b: Bool, +order: Cmp) -> {Word.cmp.fin(a, b, order) == compose(order, Bool.cmp(a, b)) : Cmp}:
  match order:
    case LT{}:
      {==}
    case EQ{}:
      {==}
    case GT{}:
      {==}

def word_fin_chain(+a: Bool, +b: Bool, +c: Bool, +x: Cmp, +y: Cmp, +z: Cmp,
  tails: {chain(x, y, z) == True{} : Bool}, heads: {chain(Bool.cmp(a, b), Bool.cmp(b, c), Bool.cmp(a, c)) == True{} : Bool}) ->
  {chain(Word.cmp.fin(a, b, x), Word.cmp.fin(b, c, y), Word.cmp.fin(a, c, z)) == True{} : Bool}:
  Equal.trans(Bool, chain(Word.cmp.fin(a, b, x), Word.cmp.fin(b, c, y), Word.cmp.fin(a, c, z)),
    chain(compose(x, Bool.cmp(a, b)), compose(y, Bool.cmp(b, c)), compose(z, Bool.cmp(a, c))), True{},
    chain_cong(Word.cmp.fin(a, b, x), Word.cmp.fin(b, c, y), Word.cmp.fin(a, c, z),
      compose(x, Bool.cmp(a, b)), compose(y, Bool.cmp(b, c)), compose(z, Bool.cmp(a, c)), fin_compose(a, b, x), fin_compose(b, c, y), fin_compose(a, c, z)),
    compose_chain(x, y, z, Bool.cmp(a, b), Bool.cmp(b, c), Bool.cmp(a, c), tails, heads))

def word_chain(n: Nat, +a: Word(n), +b: Word(n), +c: Word(n)) -> {chain(Word.cmp(n, a, b), Word.cmp(n, b, c), Word.cmp(n, a, c)) == True{} : Bool}:
  match n:
    case 0n:
      {==}
    case Succ{+p}:
      match a b c:
        case WCon{+ah, +at} WCon{+bh, +bt} WCon{+ch, +ct}:
          word_fin_chain(ah, bh, ch, Word.cmp(p, at, bt), Word.cmp(p, bt, ct), Word.cmp(p, at, ct), word_chain(p, at, bt, ct), bool_chain(ah, bh, ch))

def u32_chain(+a: U32, +b: U32, +c: U32) -> {chain(U32.cmp(a, b), U32.cmp(b, c), U32.cmp(a, c)) == True{} : Bool}:
  match a b c:
    case U32{+x} U32{+y} U32{+z}:
      word_chain(32n, x, y, z)

def go_compose(+a: String, +b: String, +order: Cmp) -> {String.order.go(a, b, order) == compose(order, String.order(a, b)) : Cmp}:
  match a b order:
    case SNil{} SNil{} LT{}:
      {==}
    case SNil{} SNil{} EQ{}:
      {==}
    case SNil{} SNil{} GT{}:
      {==}
    case SNil{} SCon{Chr{y}, bt} LT{}:
      {==}
    case SNil{} SCon{Chr{y}, bt} EQ{}:
      {==}
    case SNil{} SCon{Chr{y}, bt} GT{}:
      {==}
    case SCon{Chr{x}, at} SNil{} LT{}:
      {==}
    case SCon{Chr{x}, at} SNil{} EQ{}:
      {==}
    case SCon{Chr{x}, at} SNil{} GT{}:
      {==}
    case SCon{Chr{x}, at} SCon{Chr{y}, bt} LT{}:
      {==}
    case SCon{Chr{x}, at} SCon{Chr{y}, bt} EQ{}:
      {==}
    case SCon{Chr{x}, at} SCon{Chr{y}, bt} GT{}:
      {==}

def chain_left_min(order: Cmp) -> {chain(LT{}, order, LT{}) == True{} : Bool}:
  match order:
    case LT{}:
      {==}
    case EQ{}:
      {==}
    case GT{}:
      {==}

def chain_right_max(order: Cmp) -> {chain(order, GT{}, GT{}) == True{} : Bool}:
  match order:
    case LT{}:
      {==}
    case EQ{}:
      {==}
    case GT{}:
      {==}

def string_chain(+a: String, +b: String, +c: String) -> {chain(String.order(a, b), String.order(b, c), String.order(a, c)) == True{} : Bool}:
  match a b c:
    case SNil{} SNil{} SNil{}:
      {==}
    case SNil{} SNil{} SCon{Chr{z}, ct}:
      {==}
    case SNil{} SCon{Chr{y}, bt} SNil{}:
      {==}
    case SNil{} SCon{Chr{+y}, +bt} SCon{Chr{+z}, +ct}:
      chain_left_min(String.order(SCon{Chr{y}, bt}, SCon{Chr{z}, ct}))
    case SCon{Chr{x}, at} SNil{} SNil{}:
      {==}
    case SCon{Chr{x}, at} SNil{} SCon{Chr{z}, ct}:
      {==}
    case SCon{Chr{+x}, +at} SCon{Chr{+y}, +bt} SNil{}:
      chain_right_max(String.order(SCon{Chr{x}, at}, SCon{Chr{y}, bt}))
    case SCon{Chr{+x}, +at} SCon{Chr{+y}, +bt} SCon{Chr{+z}, +ct}:
      Equal.trans(Bool,
        chain(String.order.go(at, bt, U32.cmp(x, y)), String.order.go(bt, ct, U32.cmp(y, z)), String.order.go(at, ct, U32.cmp(x, z))),
        chain(compose(U32.cmp(x, y), String.order(at, bt)), compose(U32.cmp(y, z), String.order(bt, ct)), compose(U32.cmp(x, z), String.order(at, ct))), True{},
        chain_cong(String.order.go(at, bt, U32.cmp(x, y)), String.order.go(bt, ct, U32.cmp(y, z)), String.order.go(at, ct, U32.cmp(x, z)),
          compose(U32.cmp(x, y), String.order(at, bt)), compose(U32.cmp(y, z), String.order(bt, ct)), compose(U32.cmp(x, z), String.order(at, ct)),
          go_compose(at, bt, U32.cmp(x, y)), go_compose(bt, ct, U32.cmp(y, z)), go_compose(at, ct, U32.cmp(x, z))),
        compose_chain(U32.cmp(x, y), U32.cmp(y, z), U32.cmp(x, z), String.order(at, bt), String.order(bt, ct), String.order(at, ct),
          u32_chain(x, y, z), string_chain(at, bt, ct)))

def chain_le(+a: Cmp, +b: Cmp, +c: Cmp, ab: {Cmp.is_le(a) == True{} : Bool}, bc: {Cmp.is_le(b) == True{} : Bool}, link: {chain(a, b, c) == True{} : Bool}) -> {Cmp.is_le(c) == True{} : Bool}:
  match a b c:
    case LT{} LT{} LT{}:
      {==}
    case LT{} LT{} EQ{}:
      Empty.absurd({Cmp.is_le(EQ{}) == True{} : Bool}, false_not_true(link))
    case LT{} LT{} GT{}:
      Empty.absurd({Cmp.is_le(GT{}) == True{} : Bool}, false_not_true(link))
    case LT{} EQ{} LT{}:
      {==}
    case LT{} EQ{} EQ{}:
      Empty.absurd({Cmp.is_le(EQ{}) == True{} : Bool}, false_not_true(link))
    case LT{} EQ{} GT{}:
      Empty.absurd({Cmp.is_le(GT{}) == True{} : Bool}, false_not_true(link))
    case LT{} GT{} LT{}:
      Empty.absurd({Cmp.is_le(LT{}) == True{} : Bool}, false_not_true(bc))
    case LT{} GT{} EQ{}:
      Empty.absurd({Cmp.is_le(EQ{}) == True{} : Bool}, false_not_true(bc))
    case LT{} GT{} GT{}:
      Empty.absurd({Cmp.is_le(GT{}) == True{} : Bool}, false_not_true(bc))
    case EQ{} LT{} LT{}:
      {==}
    case EQ{} LT{} EQ{}:
      Empty.absurd({Cmp.is_le(EQ{}) == True{} : Bool}, false_not_true(link))
    case EQ{} LT{} GT{}:
      Empty.absurd({Cmp.is_le(GT{}) == True{} : Bool}, false_not_true(link))
    case EQ{} EQ{} LT{}:
      Empty.absurd({Cmp.is_le(LT{}) == True{} : Bool}, false_not_true(link))
    case EQ{} EQ{} EQ{}:
      {==}
    case EQ{} EQ{} GT{}:
      Empty.absurd({Cmp.is_le(GT{}) == True{} : Bool}, false_not_true(link))
    case EQ{} GT{} LT{}:
      Empty.absurd({Cmp.is_le(LT{}) == True{} : Bool}, false_not_true(bc))
    case EQ{} GT{} EQ{}:
      Empty.absurd({Cmp.is_le(EQ{}) == True{} : Bool}, false_not_true(bc))
    case EQ{} GT{} GT{}:
      Empty.absurd({Cmp.is_le(GT{}) == True{} : Bool}, false_not_true(bc))
    case GT{} LT{} LT{}:
      Empty.absurd({Cmp.is_le(LT{}) == True{} : Bool}, false_not_true(ab))
    case GT{} LT{} EQ{}:
      Empty.absurd({Cmp.is_le(EQ{}) == True{} : Bool}, false_not_true(ab))
    case GT{} LT{} GT{}:
      Empty.absurd({Cmp.is_le(GT{}) == True{} : Bool}, false_not_true(ab))
    case GT{} EQ{} LT{}:
      Empty.absurd({Cmp.is_le(LT{}) == True{} : Bool}, false_not_true(ab))
    case GT{} EQ{} EQ{}:
      Empty.absurd({Cmp.is_le(EQ{}) == True{} : Bool}, false_not_true(ab))
    case GT{} EQ{} GT{}:
      Empty.absurd({Cmp.is_le(GT{}) == True{} : Bool}, false_not_true(ab))
    case GT{} GT{} LT{}:
      Empty.absurd({Cmp.is_le(LT{}) == True{} : Bool}, false_not_true(ab))
    case GT{} GT{} EQ{}:
      Empty.absurd({Cmp.is_le(EQ{}) == True{} : Bool}, false_not_true(ab))
    case GT{} GT{} GT{}:
      Empty.absurd({Cmp.is_le(GT{}) == True{} : Bool}, false_not_true(ab))

def chain_total(+a: Cmp, +b: Cmp, link: {chain(a, b, EQ{}) == True{} : Bool}) -> {Bool.or(Cmp.is_le(a), Cmp.is_le(b)) == True{} : Bool}:
  match a b:
    case LT{} LT{}:
      {==}
    case LT{} EQ{}:
      {==}
    case LT{} GT{}:
      {==}
    case EQ{} LT{}:
      {==}
    case EQ{} EQ{}:
      {==}
    case EQ{} GT{}:
      {==}
    case GT{} LT{}:
      {==}
    case GT{} EQ{}:
      {==}
    case GT{} GT{}:
      Empty.absurd({Bool.or(Cmp.is_le(GT{}), Cmp.is_le(GT{})) == True{} : Bool}, false_not_true(link))

def chain_antisym(+a: Cmp, +b: Cmp, ab: {Cmp.is_le(a) == True{} : Bool}, ba: {Cmp.is_le(b) == True{} : Bool}, link: {chain(a, b, EQ{}) == True{} : Bool}) -> {a == EQ{} : Cmp}:
  match a b:
    case LT{} LT{}:
      Empty.absurd({LT{} == EQ{} : Cmp}, false_not_true(link))
    case LT{} EQ{}:
      Empty.absurd({LT{} == EQ{} : Cmp}, false_not_true(link))
    case LT{} GT{}:
      Empty.absurd({LT{} == EQ{} : Cmp}, false_not_true(ba))
    case EQ{} LT{}:
      {==}
    case EQ{} EQ{}:
      {==}
    case EQ{} GT{}:
      {==}
    case GT{} LT{}:
      Empty.absurd({GT{} == EQ{} : Cmp}, false_not_true(ab))
    case GT{} EQ{}:
      Empty.absurd({GT{} == EQ{} : Cmp}, false_not_true(ab))
    case GT{} GT{}:
      Empty.absurd({GT{} == EQ{} : Cmp}, false_not_true(ab))

# Public theorem API. Premises are comparator results, never the desired output.
def string_loop_link(+a: String, +b: String) -> {chain(String.order(a, b), String.order(b, a), EQ{}) == True{} : Bool}:
  Equal.trans(Bool, chain(String.order(a, b), String.order(b, a), EQ{}), chain(String.order(a, b), String.order(b, a), String.order(a, a)), True{},
    Equal.sym(Bool, chain(String.order(a, b), String.order(b, a), String.order(a, a)), chain(String.order(a, b), String.order(b, a), EQ{}),
      Equal.cong(Cmp, Bool, c => chain(String.order(a, b), String.order(b, a), c), String.order(a, a), EQ{}, string_order_reflexive(a))),
    string_chain(a, b, a))

def string_le_refl(+s: String) -> {String.is_le(s, s) == True{} : Bool}:
  Equal.cong(Cmp, Bool, c => Cmp.is_le(c), String.order(s, s), EQ{}, string_order_reflexive(s))

def string_le_trans(+a: String, +b: String, +c: String,
  ab: {String.is_le(a, b) == True{} : Bool}, bc: {String.is_le(b, c) == True{} : Bool}) -> {String.is_le(a, c) == True{} : Bool}:
  chain_le(String.order(a, b), String.order(b, c), String.order(a, c), ab, bc, string_chain(a, b, c))

def string_le_total(+a: String, +b: String) -> {Bool.or(String.is_le(a, b), String.is_le(b, a)) == True{} : Bool}:
  chain_total(String.order(a, b), String.order(b, a), string_loop_link(a, b))

def string_le_antisym(+a: String, +b: String,
  ab: {String.is_le(a, b) == True{} : Bool}, ba: {String.is_le(b, a) == True{} : Bool}) -> {a == b : String}:
  string_order_equality_sound(a, b, chain_antisym(String.order(a, b), String.order(b, a), ab, ba, string_loop_link(a, b)))

def string_le_from_equal(+a: String, +b: String, equality: {a == b : String}) -> {String.is_le(a, b) == True{} : Bool}:
  Equal.trans(Bool, String.is_le(a, b), String.is_le(a, a), True{},
    Equal.sym(Bool, String.is_le(a, a), String.is_le(a, b), Equal.cong(String, Bool, s => String.is_le(a, s), a, b, equality)),
    string_le_refl(a))

def string_eq_le(+a: String, +b: String, equality: {String.eq(a, b) == True{} : Bool}) -> {String.is_le(a, b) == True{} : Bool}:
  string_le_from_equal(a, b, string_equality_sound(a, b, equality))

law order_has_distinct_witness:
  {Bool.and(String.is_le("a", "b"), Bool.not(String.is_le("b", "a"))) == True{} : Bool}

def order_has_distinct_witness():
  {==}
