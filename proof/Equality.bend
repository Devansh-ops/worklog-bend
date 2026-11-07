import Base
import ../bend/Types.bend as T
import ../bend/Core.bend as Core

# Independent reusable reflection of the actual full event comparator.
# Extracted from already checked root proofs without changing their statements.

def false_true_discriminator(value: Bool) -> Type:
  match value:
    case False{}:
      Empty
    case True{}:
      Unit

def word_order_reflexive(n: Nat, w: Word(n)) -> {Word.cmp(n, w, w) == EQ{} : Cmp}:
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

def u32_order_reflexive(x: U32) -> {U32.cmp(x, x) == EQ{} : Cmp}:
  match x:
    case U32{w}:
      word_order_reflexive(32n, w)

def string_order_reflexive(s: String) -> {String.order(s, s) == EQ{} : Cmp}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{x}, t}:
      Equal.trans(Cmp, String.order.go(t, t, U32.cmp(x, x)), String.order(t, t), EQ{},
        Equal.cong(Cmp, Cmp, c => String.order.go(t, t, c),
          U32.cmp(x, x), EQ{}, u32_order_reflexive(x)),
        string_order_reflexive(t))

def string_equality_reflexive(s: String) -> {String.eq(s, s) == True{} : Bool}:
  Equal.cong(Cmp, Bool, c => Cmp.is_eq(c),
    String.order(s, s), EQ{}, string_order_reflexive(s))

def true_and(-a: Bool, -b: Bool, pa: {a == True{} : Bool}, pb: {b == True{} : Bool}) -> {Bool.and(a, b) == True{} : Bool}:
  %Equal.sym(Bool, a, True{}, pa) : {Bool.and(_, b) == True{} : Bool}
  pb

def bool_equality_reflexive(b: Bool) -> {Core.bool_eq(b, b) == True{} : Bool}:
  match b:
    case False{}:
      {==}
    case True{}:
      {==}

def status_equality_reflexive(status: T.Status) -> {Core.status_eq(status, status) == True{} : Bool}:
  match status:
    case T.SBacklog{}:
      {==}
    case T.STodo{}:
      {==}
    case T.SProgress{}:
      {==}
    case T.SBlocked{}:
      {==}
    case T.SReview{}:
      {==}
    case T.SDone{}:
      {==}

def priority_equality_reflexive(priority: T.Priority) -> {Core.priority_eq(priority, priority) == True{} : Bool}:
  match priority:
    case T.PLow{}:
      {==}
    case T.PNormal{}:
      {==}
    case T.PHigh{}:
      {==}
    case T.PUrgent{}:
      {==}

def strings_equality_reflexive(strings: List<&2, String>) -> {Core.strings_eq(strings, strings) == True{} : Bool}:
  match strings:
    case Nil{}:
      {==}
    case h <> t:
      true_and(String.eq(h, h), Core.strings_eq(t, t),
        string_equality_reflexive(h), strings_equality_reflexive(t))

def optional_string_equality_reflexive(value: Maybe<&2, String>) -> {Core.optional_string_eq(value, value) == True{} : Bool}:
  match value:
    case None{}:
      {==}
    case Some{x}:
      string_equality_reflexive(x)

def optional_status_equality_reflexive(value: Maybe<&2, T.Status>) -> {Core.optional_status_eq(value, value) == True{} : Bool}:
  match value:
    case None{}:
      {==}
    case Some{x}:
      status_equality_reflexive(x)

def optional_priority_equality_reflexive(value: Maybe<&2, T.Priority>) -> {Core.optional_priority_eq(value, value) == True{} : Bool}:
  match value:
    case None{}:
      {==}
    case Some{x}:
      priority_equality_reflexive(x)

def optional_strings_equality_reflexive(value: Maybe<&2, List<&2, String>>) -> {Core.optional_strings_eq(value, value) == True{} : Bool}:
  match value:
    case None{}:
      {==}
    case Some{x}:
      strings_equality_reflexive(x)

def optional_bool_equality_reflexive(value: Maybe<&2, Bool>) -> {Core.optional_bool_eq(value, value) == True{} : Bool}:
  match value:
    case None{}:
      {==}
    case Some{x}:
      bool_equality_reflexive(x)

def patch_equality_reflexive(patch: T.Patch) -> {Core.patch_eq(patch, patch) == True{} : Bool}:
  match patch:
    case T.Patch{title, status, priority, tags, private}:
      true_and(Core.optional_string_eq(title, title), Bool.and(Core.optional_status_eq(status, status), Bool.and(Core.optional_priority_eq(priority, priority), Bool.and(Core.optional_strings_eq(tags, tags), Core.optional_bool_eq(private, private)))),
        optional_string_equality_reflexive(title),
        true_and(Core.optional_status_eq(status, status), Bool.and(Core.optional_priority_eq(priority, priority), Bool.and(Core.optional_strings_eq(tags, tags), Core.optional_bool_eq(private, private))),
          optional_status_equality_reflexive(status),
          true_and(Core.optional_priority_eq(priority, priority), Bool.and(Core.optional_strings_eq(tags, tags), Core.optional_bool_eq(private, private)),
            optional_priority_equality_reflexive(priority),
            true_and(Core.optional_strings_eq(tags, tags), Core.optional_bool_eq(private, private), optional_strings_equality_reflexive(tags), optional_bool_equality_reflexive(private)))))

def payload_equality_reflexive(payload: T.Payload) -> {Core.payload_eq(payload, payload) == True{} : Bool}:
  match payload:
    case T.Created{id, title, status, priority, tags, private}:
      true_and(String.eq(id, id), Bool.and(String.eq(title, title), Bool.and(Core.status_eq(status, status), Bool.and(Core.priority_eq(priority, priority), Bool.and(Core.strings_eq(tags, tags), Core.bool_eq(private, private))))),
        string_equality_reflexive(id),
        true_and(String.eq(title, title), Bool.and(Core.status_eq(status, status), Bool.and(Core.priority_eq(priority, priority), Bool.and(Core.strings_eq(tags, tags), Core.bool_eq(private, private)))),
          string_equality_reflexive(title),
          true_and(Core.status_eq(status, status), Bool.and(Core.priority_eq(priority, priority), Bool.and(Core.strings_eq(tags, tags), Core.bool_eq(private, private))),
            status_equality_reflexive(status),
            true_and(Core.priority_eq(priority, priority), Bool.and(Core.strings_eq(tags, tags), Core.bool_eq(private, private)),
              priority_equality_reflexive(priority),
              true_and(Core.strings_eq(tags, tags), Core.bool_eq(private, private), strings_equality_reflexive(tags), bool_equality_reflexive(private))))))
    case T.StatusChanged{id, status}:
      true_and(String.eq(id, id), Core.status_eq(status, status), string_equality_reflexive(id), status_equality_reflexive(status))
    case T.Noted{id, text}:
      true_and(String.eq(id, id), String.eq(text, text), string_equality_reflexive(id), string_equality_reflexive(text))
    case T.Edited{id, patch}:
      true_and(String.eq(id, id), Core.patch_eq(patch, patch), string_equality_reflexive(id), patch_equality_reflexive(patch))
    case T.Deleted{id}:
      string_equality_reflexive(id)
    case T.SummarySet{date, kind, body}:
      true_and(String.eq(date, date), Bool.and(String.eq(kind, kind), String.eq(body, body)), string_equality_reflexive(date),
        true_and(String.eq(kind, kind), String.eq(body, body), string_equality_reflexive(kind), string_equality_reflexive(body)))
    case T.StandupSet{date, kind, text}:
      true_and(String.eq(date, date), Bool.and(String.eq(kind, kind), String.eq(text, text)), string_equality_reflexive(date),
        true_and(String.eq(kind, kind), String.eq(text, text), string_equality_reflexive(kind), string_equality_reflexive(text)))
    case T.Opaque{kind}:
      string_equality_reflexive(kind)

def event_equality_reflexive(event: T.DomainEvent) -> {Core.event_eq(event, event) == True{} : Bool}:
  match event:
    case T.Ev{id, ts, day, payload, canonical}:
      true_and(String.eq(id, id), Bool.and(String.eq(ts, ts), Bool.and(String.eq(day, day), Bool.and(Core.payload_eq(payload, payload), String.eq(canonical, canonical)))),
        string_equality_reflexive(id),
        true_and(String.eq(ts, ts), Bool.and(String.eq(day, day), Bool.and(Core.payload_eq(payload, payload), String.eq(canonical, canonical))),
          string_equality_reflexive(ts),
          true_and(String.eq(day, day), Bool.and(Core.payload_eq(payload, payload), String.eq(canonical, canonical)),
            string_equality_reflexive(day),
            true_and(Core.payload_eq(payload, payload), String.eq(canonical, canonical), payload_equality_reflexive(payload), string_equality_reflexive(canonical)))))

def false_is_not_true(contradiction: {False{} == True{} : Bool}) -> Empty:
  %Equal.sym(Bool, False{}, True{}, contradiction) : false_true_discriminator(_)
  Unit{}

def bool_order_equality_sound(a: Bool, b: Bool, equality: {Bool.cmp(a, b) == EQ{} : Cmp}) -> {a == b : Bool}:
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      Equal.cong(Cmp, Bool, c => Cmp.is_eq(c), LT{}, EQ{}, equality)
    case True{} False{}:
      Equal.sym(Bool, False{}, True{}, Equal.cong(Cmp, Bool, c => Cmp.is_eq(c), GT{}, EQ{}, equality))
    case True{} True{}:
      {==}

def word_cmp_fin_tail(a: Bool, b: Bool, tail: Cmp, equality: {Word.cmp.fin(a, b, tail) == EQ{} : Cmp}) -> {tail == EQ{} : Cmp}:
  match tail:
    case LT{}:
      equality
    case EQ{}:
      {==}
    case GT{}:
      equality

def word_cmp_fin_head(a: Bool, b: Bool, tail: Cmp, tail_equal: {tail == EQ{} : Cmp}, equality: {Word.cmp.fin(a, b, tail) == EQ{} : Cmp}) -> {Bool.cmp(a, b) == EQ{} : Cmp}:
  Equal.trans(Cmp, Bool.cmp(a, b), Word.cmp.fin(a, b, tail), EQ{},
    Equal.sym(Cmp, Word.cmp.fin(a, b, tail), Bool.cmp(a, b),
      Equal.cong(Cmp, Cmp, c => Word.cmp.fin(a, b, c), tail, EQ{}, tail_equal)),
    equality)

def word_order_equality_sound(n: Nat, a: Word(n), b: Word(n), +equality: {Word.cmp(n, a, b) == EQ{} : Cmp}) -> {a == b : Word(n)}:
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

def u32_order_equality_sound(a: U32, b: U32, equality: {U32.cmp(a, b) == EQ{} : Cmp}) -> {a == b : U32}:
  match a b:
    case U32{x} U32{y}:
      Equal.cong(Word(32n), U32, bits => U32{bits}, x, y,
        word_order_equality_sound(32n, x, y, equality))

def string_order_go_lt(a: String, b: String) -> {String.order.go(a, b, LT{}) == LT{} : Cmp}:
  match a b:
    case SNil{} SNil{}:
      {==}
    case SNil{} SCon{h, t}:
      {==}
    case SCon{h, t} SNil{}:
      {==}
    case SCon{Chr{x}, at} SCon{Chr{y}, bt}:
      {==}

def string_order_go_gt(a: String, b: String) -> {String.order.go(a, b, GT{}) == GT{} : Cmp}:
  match a b:
    case SNil{} SNil{}:
      {==}
    case SNil{} SCon{h, t}:
      {==}
    case SCon{h, t} SNil{}:
      {==}
    case SCon{Chr{x}, at} SCon{Chr{y}, bt}:
      {==}

def string_order_go_eq_premise(a: String, b: String, order: Cmp, equality: {String.order.go(a, b, order) == EQ{} : Cmp}) -> {order == EQ{} : Cmp}:
  match order:
    case LT{}:
      Equal.trans(Cmp, LT{}, String.order.go(a, b, LT{}), EQ{},
        Equal.sym(Cmp, String.order.go(a, b, LT{}), LT{}, string_order_go_lt(a, b)), equality)
    case EQ{}:
      {==}
    case GT{}:
      Equal.trans(Cmp, GT{}, String.order.go(a, b, GT{}), EQ{},
        Equal.sym(Cmp, String.order.go(a, b, GT{}), GT{}, string_order_go_gt(a, b)), equality)

def string_order_equality_sound(a: String, b: String, +equality: {String.order(a, b) == EQ{} : Cmp}) -> {a == b : String}:
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

def cmp_is_eq_sound(order: Cmp, equality: {Cmp.is_eq(order) == True{} : Bool}) -> {order == EQ{} : Cmp}:
  match order:
    case LT{}:
      Empty.absurd({LT{} == EQ{} : Cmp}, false_is_not_true(equality))
    case EQ{}:
      {==}
    case GT{}:
      Empty.absurd({GT{} == EQ{} : Cmp}, false_is_not_true(equality))

def string_equality_sound(+a: String, +b: String, equality: {String.eq(a, b) == True{} : Bool}) -> {a == b : String}:
  string_order_equality_sound(a, b,
    cmp_is_eq_sound(String.order(a, b), equality))

def bool_not_true_is_false(value: Bool, reject: {value == True{} : Bool} -> Empty) -> {value == False{} : Bool}:
  match value:
    case False{}:
      {==}
    case True{}:
      Empty.absurd({True{} == False{} : Bool}, reject({==}))

def and_true_right(a: Bool, b: Bool, equality: {Bool.and(a, b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case False{}:
      Empty.absurd({b == True{} : Bool}, false_is_not_true(equality))
    case True{}:
      equality

def and_true_left(a: Bool, b: Bool, equality: {Bool.and(a, b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case False{}:
      equality
    case True{}:
      {==}

def status_equality_sound(a: T.Status, b: T.Status, equality: {Core.status_eq(a, b) == True{} : Bool}) -> {a == b : T.Status}:
  match a b:
    case T.SBacklog{} T.SBacklog{}:
      {==}
    case T.SBacklog{} T.STodo{}:
      Empty.absurd({T.SBacklog{} == T.STodo{} : T.Status}, false_is_not_true(equality))
    case T.SBacklog{} T.SProgress{}:
      Empty.absurd({T.SBacklog{} == T.SProgress{} : T.Status}, false_is_not_true(equality))
    case T.SBacklog{} T.SBlocked{}:
      Empty.absurd({T.SBacklog{} == T.SBlocked{} : T.Status}, false_is_not_true(equality))
    case T.SBacklog{} T.SReview{}:
      Empty.absurd({T.SBacklog{} == T.SReview{} : T.Status}, false_is_not_true(equality))
    case T.SBacklog{} T.SDone{}:
      Empty.absurd({T.SBacklog{} == T.SDone{} : T.Status}, false_is_not_true(equality))
    case T.STodo{} T.SBacklog{}:
      Empty.absurd({T.STodo{} == T.SBacklog{} : T.Status}, false_is_not_true(equality))
    case T.STodo{} T.STodo{}:
      {==}
    case T.STodo{} T.SProgress{}:
      Empty.absurd({T.STodo{} == T.SProgress{} : T.Status}, false_is_not_true(equality))
    case T.STodo{} T.SBlocked{}:
      Empty.absurd({T.STodo{} == T.SBlocked{} : T.Status}, false_is_not_true(equality))
    case T.STodo{} T.SReview{}:
      Empty.absurd({T.STodo{} == T.SReview{} : T.Status}, false_is_not_true(equality))
    case T.STodo{} T.SDone{}:
      Empty.absurd({T.STodo{} == T.SDone{} : T.Status}, false_is_not_true(equality))
    case T.SProgress{} T.SBacklog{}:
      Empty.absurd({T.SProgress{} == T.SBacklog{} : T.Status}, false_is_not_true(equality))
    case T.SProgress{} T.STodo{}:
      Empty.absurd({T.SProgress{} == T.STodo{} : T.Status}, false_is_not_true(equality))
    case T.SProgress{} T.SProgress{}:
      {==}
    case T.SProgress{} T.SBlocked{}:
      Empty.absurd({T.SProgress{} == T.SBlocked{} : T.Status}, false_is_not_true(equality))
    case T.SProgress{} T.SReview{}:
      Empty.absurd({T.SProgress{} == T.SReview{} : T.Status}, false_is_not_true(equality))
    case T.SProgress{} T.SDone{}:
      Empty.absurd({T.SProgress{} == T.SDone{} : T.Status}, false_is_not_true(equality))
    case T.SBlocked{} T.SBacklog{}:
      Empty.absurd({T.SBlocked{} == T.SBacklog{} : T.Status}, false_is_not_true(equality))
    case T.SBlocked{} T.STodo{}:
      Empty.absurd({T.SBlocked{} == T.STodo{} : T.Status}, false_is_not_true(equality))
    case T.SBlocked{} T.SProgress{}:
      Empty.absurd({T.SBlocked{} == T.SProgress{} : T.Status}, false_is_not_true(equality))
    case T.SBlocked{} T.SBlocked{}:
      {==}
    case T.SBlocked{} T.SReview{}:
      Empty.absurd({T.SBlocked{} == T.SReview{} : T.Status}, false_is_not_true(equality))
    case T.SBlocked{} T.SDone{}:
      Empty.absurd({T.SBlocked{} == T.SDone{} : T.Status}, false_is_not_true(equality))
    case T.SReview{} T.SBacklog{}:
      Empty.absurd({T.SReview{} == T.SBacklog{} : T.Status}, false_is_not_true(equality))
    case T.SReview{} T.STodo{}:
      Empty.absurd({T.SReview{} == T.STodo{} : T.Status}, false_is_not_true(equality))
    case T.SReview{} T.SProgress{}:
      Empty.absurd({T.SReview{} == T.SProgress{} : T.Status}, false_is_not_true(equality))
    case T.SReview{} T.SBlocked{}:
      Empty.absurd({T.SReview{} == T.SBlocked{} : T.Status}, false_is_not_true(equality))
    case T.SReview{} T.SReview{}:
      {==}
    case T.SReview{} T.SDone{}:
      Empty.absurd({T.SReview{} == T.SDone{} : T.Status}, false_is_not_true(equality))
    case T.SDone{} T.SBacklog{}:
      Empty.absurd({T.SDone{} == T.SBacklog{} : T.Status}, false_is_not_true(equality))
    case T.SDone{} T.STodo{}:
      Empty.absurd({T.SDone{} == T.STodo{} : T.Status}, false_is_not_true(equality))
    case T.SDone{} T.SProgress{}:
      Empty.absurd({T.SDone{} == T.SProgress{} : T.Status}, false_is_not_true(equality))
    case T.SDone{} T.SBlocked{}:
      Empty.absurd({T.SDone{} == T.SBlocked{} : T.Status}, false_is_not_true(equality))
    case T.SDone{} T.SReview{}:
      Empty.absurd({T.SDone{} == T.SReview{} : T.Status}, false_is_not_true(equality))
    case T.SDone{} T.SDone{}:
      {==}

def priority_equality_sound(a: T.Priority, b: T.Priority, equality: {Core.priority_eq(a, b) == True{} : Bool}) -> {a == b : T.Priority}:
  match a b:
    case T.PLow{} T.PLow{}:
      {==}
    case T.PLow{} T.PNormal{}:
      Empty.absurd({T.PLow{} == T.PNormal{} : T.Priority}, false_is_not_true(equality))
    case T.PLow{} T.PHigh{}:
      Empty.absurd({T.PLow{} == T.PHigh{} : T.Priority}, false_is_not_true(equality))
    case T.PLow{} T.PUrgent{}:
      Empty.absurd({T.PLow{} == T.PUrgent{} : T.Priority}, false_is_not_true(equality))
    case T.PNormal{} T.PLow{}:
      Empty.absurd({T.PNormal{} == T.PLow{} : T.Priority}, false_is_not_true(equality))
    case T.PNormal{} T.PNormal{}:
      {==}
    case T.PNormal{} T.PHigh{}:
      Empty.absurd({T.PNormal{} == T.PHigh{} : T.Priority}, false_is_not_true(equality))
    case T.PNormal{} T.PUrgent{}:
      Empty.absurd({T.PNormal{} == T.PUrgent{} : T.Priority}, false_is_not_true(equality))
    case T.PHigh{} T.PLow{}:
      Empty.absurd({T.PHigh{} == T.PLow{} : T.Priority}, false_is_not_true(equality))
    case T.PHigh{} T.PNormal{}:
      Empty.absurd({T.PHigh{} == T.PNormal{} : T.Priority}, false_is_not_true(equality))
    case T.PHigh{} T.PHigh{}:
      {==}
    case T.PHigh{} T.PUrgent{}:
      Empty.absurd({T.PHigh{} == T.PUrgent{} : T.Priority}, false_is_not_true(equality))
    case T.PUrgent{} T.PLow{}:
      Empty.absurd({T.PUrgent{} == T.PLow{} : T.Priority}, false_is_not_true(equality))
    case T.PUrgent{} T.PNormal{}:
      Empty.absurd({T.PUrgent{} == T.PNormal{} : T.Priority}, false_is_not_true(equality))
    case T.PUrgent{} T.PHigh{}:
      Empty.absurd({T.PUrgent{} == T.PHigh{} : T.Priority}, false_is_not_true(equality))
    case T.PUrgent{} T.PUrgent{}:
      {==}

def bool_equality_sound(+a: Bool, +b: Bool, equality: {Core.bool_eq(a, b) == True{} : Bool}) -> {a == b : Bool}:
  bool_order_equality_sound(a, b, cmp_is_eq_sound(Bool.cmp(a, b), equality))

def strings_equality_sound(a: List<&2, String>, b: List<&2, String>, +equality: {Core.strings_eq(a, b) == True{} : Bool}) -> {a == b : List<&2, String>}:
  match a b:
    case Nil{} Nil{}:
      {==}
    case Nil{} h <> t:
      Empty.absurd({Nil{} == h <> t : List<&2, String>}, false_is_not_true(equality))
    case h <> t Nil{}:
      Empty.absurd({h <> t == Nil{} : List<&2, String>}, false_is_not_true(equality))
    case +ah <> +at +bh <> +bt:
      head = string_equality_sound(ah, bh, and_true_left(String.eq(ah, bh), Core.strings_eq(at, bt), equality))
      tail = strings_equality_sound(at, bt, and_true_right(String.eq(ah, bh), Core.strings_eq(at, bt), equality))
      %head : {ah <> at == _ <> bt : List<&2, String>}
      %tail : {ah <> at == ah <> _ : List<&2, String>}
      {==}

def optional_string_equality_sound(a: Maybe<&2, String>, b: Maybe<&2, String>, equality: {Core.optional_string_eq(a, b) == True{} : Bool}) -> {a == b : Maybe<&2, String>}:
  match a b:
    case None{} None{}:
      {==}
    case None{} Some{y}:
      Empty.absurd({None{} == Some{y} : Maybe<&2, String>}, false_is_not_true(equality))
    case Some{x} None{}:
      Empty.absurd({Some{x} == None{} : Maybe<&2, String>}, false_is_not_true(equality))
    case Some{x} Some{y}:
      Equal.cong(String, Maybe<&2, String>, value => Some{value}, x, y, string_equality_sound(x, y, equality))

def optional_status_equality_sound(a: Maybe<&2, T.Status>, b: Maybe<&2, T.Status>, equality: {Core.optional_status_eq(a, b) == True{} : Bool}) -> {a == b : Maybe<&2, T.Status>}:
  match a b:
    case None{} None{}:
      {==}
    case None{} Some{y}:
      Empty.absurd({None{} == Some{y} : Maybe<&2, T.Status>}, false_is_not_true(equality))
    case Some{x} None{}:
      Empty.absurd({Some{x} == None{} : Maybe<&2, T.Status>}, false_is_not_true(equality))
    case Some{x} Some{y}:
      Equal.cong(T.Status, Maybe<&2, T.Status>, value => Some{value}, x, y, status_equality_sound(x, y, equality))

def optional_priority_equality_sound(a: Maybe<&2, T.Priority>, b: Maybe<&2, T.Priority>, equality: {Core.optional_priority_eq(a, b) == True{} : Bool}) -> {a == b : Maybe<&2, T.Priority>}:
  match a b:
    case None{} None{}:
      {==}
    case None{} Some{y}:
      Empty.absurd({None{} == Some{y} : Maybe<&2, T.Priority>}, false_is_not_true(equality))
    case Some{x} None{}:
      Empty.absurd({Some{x} == None{} : Maybe<&2, T.Priority>}, false_is_not_true(equality))
    case Some{x} Some{y}:
      Equal.cong(T.Priority, Maybe<&2, T.Priority>, value => Some{value}, x, y, priority_equality_sound(x, y, equality))

def optional_strings_equality_sound(a: Maybe<&2, List<&2, String>>, b: Maybe<&2, List<&2, String>>, equality: {Core.optional_strings_eq(a, b) == True{} : Bool}) -> {a == b : Maybe<&2, List<&2, String>>}:
  match a b:
    case None{} None{}:
      {==}
    case None{} Some{y}:
      Empty.absurd({None{} == Some{y} : Maybe<&2, List<&2, String>>}, false_is_not_true(equality))
    case Some{x} None{}:
      Empty.absurd({Some{x} == None{} : Maybe<&2, List<&2, String>>}, false_is_not_true(equality))
    case Some{x} Some{y}:
      Equal.cong(List<&2, String>, Maybe<&2, List<&2, String>>, value => Some{value}, x, y, strings_equality_sound(x, y, equality))

def optional_bool_equality_sound(a: Maybe<&2, Bool>, b: Maybe<&2, Bool>, equality: {Core.optional_bool_eq(a, b) == True{} : Bool}) -> {a == b : Maybe<&2, Bool>}:
  match a b:
    case None{} None{}:
      {==}
    case None{} Some{y}:
      Empty.absurd({None{} == Some{y} : Maybe<&2, Bool>}, false_is_not_true(equality))
    case Some{x} None{}:
      Empty.absurd({Some{x} == None{} : Maybe<&2, Bool>}, false_is_not_true(equality))
    case Some{x} Some{y}:
      Equal.cong(Bool, Maybe<&2, Bool>, value => Some{value}, x, y, bool_equality_sound(x, y, equality))

def patch_equality_sound(a: T.Patch, b: T.Patch, +equality: {Core.patch_eq(a, b) == True{} : Bool}) -> {a == b : T.Patch}:
  match a b:
    case T.Patch{+a0, +a1, +a2, +a3, +a4} T.Patch{+b0, +b1, +b2, +b3, +b4}:
      comparison0 = and_true_left(Core.optional_string_eq(a0, b0), Bool.and(Core.optional_status_eq(a1, b1), Bool.and(Core.optional_priority_eq(a2, b2), Bool.and(Core.optional_strings_eq(a3, b3), Core.optional_bool_eq(a4, b4)))), equality)
      +remaining1 = and_true_right(Core.optional_string_eq(a0, b0), Bool.and(Core.optional_status_eq(a1, b1), Bool.and(Core.optional_priority_eq(a2, b2), Bool.and(Core.optional_strings_eq(a3, b3), Core.optional_bool_eq(a4, b4)))), equality)
      field0 = optional_string_equality_sound(a0, b0, comparison0)
      comparison1 = and_true_left(Core.optional_status_eq(a1, b1), Bool.and(Core.optional_priority_eq(a2, b2), Bool.and(Core.optional_strings_eq(a3, b3), Core.optional_bool_eq(a4, b4))), remaining1)
      +remaining2 = and_true_right(Core.optional_status_eq(a1, b1), Bool.and(Core.optional_priority_eq(a2, b2), Bool.and(Core.optional_strings_eq(a3, b3), Core.optional_bool_eq(a4, b4))), remaining1)
      field1 = optional_status_equality_sound(a1, b1, comparison1)
      comparison2 = and_true_left(Core.optional_priority_eq(a2, b2), Bool.and(Core.optional_strings_eq(a3, b3), Core.optional_bool_eq(a4, b4)), remaining2)
      +remaining3 = and_true_right(Core.optional_priority_eq(a2, b2), Bool.and(Core.optional_strings_eq(a3, b3), Core.optional_bool_eq(a4, b4)), remaining2)
      field2 = optional_priority_equality_sound(a2, b2, comparison2)
      comparison3 = and_true_left(Core.optional_strings_eq(a3, b3), Core.optional_bool_eq(a4, b4), remaining3)
      +remaining4 = and_true_right(Core.optional_strings_eq(a3, b3), Core.optional_bool_eq(a4, b4), remaining3)
      field3 = optional_strings_equality_sound(a3, b3, comparison3)
      field4 = optional_bool_equality_sound(a4, b4, remaining4)
      %field0 : {T.Patch{a0, a1, a2, a3, a4} == T.Patch{_, b1, b2, b3, b4} : T.Patch}
      %field1 : {T.Patch{a0, a1, a2, a3, a4} == T.Patch{a0, _, b2, b3, b4} : T.Patch}
      %field2 : {T.Patch{a0, a1, a2, a3, a4} == T.Patch{a0, a1, _, b3, b4} : T.Patch}
      %field3 : {T.Patch{a0, a1, a2, a3, a4} == T.Patch{a0, a1, a2, _, b4} : T.Patch}
      %field4 : {T.Patch{a0, a1, a2, a3, a4} == T.Patch{a0, a1, a2, a3, _} : T.Patch}
      {==}

def payload_equality_sound(a: T.Payload, b: T.Payload, +equality: {Core.payload_eq(a, b) == True{} : Bool}) -> {a == b : T.Payload}:
  match a b:
    case T.Created{+a0, +a1, +a2, +a3, +a4, +a5} T.Created{+b0, +b1, +b2, +b3, +b4, +b5}:
      comparison0 = and_true_left(String.eq(a0, b0), Bool.and(String.eq(a1, b1), Bool.and(Core.status_eq(a2, b2), Bool.and(Core.priority_eq(a3, b3), Bool.and(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5))))), equality)
      +remaining1 = and_true_right(String.eq(a0, b0), Bool.and(String.eq(a1, b1), Bool.and(Core.status_eq(a2, b2), Bool.and(Core.priority_eq(a3, b3), Bool.and(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5))))), equality)
      field0 = string_equality_sound(a0, b0, comparison0)
      comparison1 = and_true_left(String.eq(a1, b1), Bool.and(Core.status_eq(a2, b2), Bool.and(Core.priority_eq(a3, b3), Bool.and(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5)))), remaining1)
      +remaining2 = and_true_right(String.eq(a1, b1), Bool.and(Core.status_eq(a2, b2), Bool.and(Core.priority_eq(a3, b3), Bool.and(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5)))), remaining1)
      field1 = string_equality_sound(a1, b1, comparison1)
      comparison2 = and_true_left(Core.status_eq(a2, b2), Bool.and(Core.priority_eq(a3, b3), Bool.and(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5))), remaining2)
      +remaining3 = and_true_right(Core.status_eq(a2, b2), Bool.and(Core.priority_eq(a3, b3), Bool.and(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5))), remaining2)
      field2 = status_equality_sound(a2, b2, comparison2)
      comparison3 = and_true_left(Core.priority_eq(a3, b3), Bool.and(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5)), remaining3)
      +remaining4 = and_true_right(Core.priority_eq(a3, b3), Bool.and(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5)), remaining3)
      field3 = priority_equality_sound(a3, b3, comparison3)
      comparison4 = and_true_left(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5), remaining4)
      +remaining5 = and_true_right(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5), remaining4)
      field4 = strings_equality_sound(a4, b4, comparison4)
      field5 = bool_equality_sound(a5, b5, remaining5)
      %field0 : {T.Created{a0, a1, a2, a3, a4, a5} == T.Created{_, b1, b2, b3, b4, b5} : T.Payload}
      %field1 : {T.Created{a0, a1, a2, a3, a4, a5} == T.Created{a0, _, b2, b3, b4, b5} : T.Payload}
      %field2 : {T.Created{a0, a1, a2, a3, a4, a5} == T.Created{a0, a1, _, b3, b4, b5} : T.Payload}
      %field3 : {T.Created{a0, a1, a2, a3, a4, a5} == T.Created{a0, a1, a2, _, b4, b5} : T.Payload}
      %field4 : {T.Created{a0, a1, a2, a3, a4, a5} == T.Created{a0, a1, a2, a3, _, b5} : T.Payload}
      %field5 : {T.Created{a0, a1, a2, a3, a4, a5} == T.Created{a0, a1, a2, a3, a4, _} : T.Payload}
      {==}
    case T.Created{+a0, +a1, +a2, +a3, +a4, +a5} T.StatusChanged{+b0, +b1}:
      Empty.absurd({T.Created{a0, a1, a2, a3, a4, a5} == T.StatusChanged{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.Created{+a0, +a1, +a2, +a3, +a4, +a5} T.Noted{+b0, +b1}:
      Empty.absurd({T.Created{a0, a1, a2, a3, a4, a5} == T.Noted{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.Created{+a0, +a1, +a2, +a3, +a4, +a5} T.Edited{+b0, +b1}:
      Empty.absurd({T.Created{a0, a1, a2, a3, a4, a5} == T.Edited{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.Created{+a0, +a1, +a2, +a3, +a4, +a5} T.Deleted{+b0}:
      Empty.absurd({T.Created{a0, a1, a2, a3, a4, a5} == T.Deleted{b0} : T.Payload}, false_is_not_true(equality))
    case T.Created{+a0, +a1, +a2, +a3, +a4, +a5} T.SummarySet{+b0, +b1, +b2}:
      Empty.absurd({T.Created{a0, a1, a2, a3, a4, a5} == T.SummarySet{b0, b1, b2} : T.Payload}, false_is_not_true(equality))
    case T.Created{+a0, +a1, +a2, +a3, +a4, +a5} T.StandupSet{+b0, +b1, +b2}:
      Empty.absurd({T.Created{a0, a1, a2, a3, a4, a5} == T.StandupSet{b0, b1, b2} : T.Payload}, false_is_not_true(equality))
    case T.Created{+a0, +a1, +a2, +a3, +a4, +a5} T.Opaque{+b0}:
      Empty.absurd({T.Created{a0, a1, a2, a3, a4, a5} == T.Opaque{b0} : T.Payload}, false_is_not_true(equality))
    case T.StatusChanged{+a0, +a1} T.Created{+b0, +b1, +b2, +b3, +b4, +b5}:
      Empty.absurd({T.StatusChanged{a0, a1} == T.Created{b0, b1, b2, b3, b4, b5} : T.Payload}, false_is_not_true(equality))
    case T.StatusChanged{+a0, +a1} T.StatusChanged{+b0, +b1}:
      comparison0 = and_true_left(String.eq(a0, b0), Core.status_eq(a1, b1), equality)
      +remaining1 = and_true_right(String.eq(a0, b0), Core.status_eq(a1, b1), equality)
      field0 = string_equality_sound(a0, b0, comparison0)
      field1 = status_equality_sound(a1, b1, remaining1)
      %field0 : {T.StatusChanged{a0, a1} == T.StatusChanged{_, b1} : T.Payload}
      %field1 : {T.StatusChanged{a0, a1} == T.StatusChanged{a0, _} : T.Payload}
      {==}
    case T.StatusChanged{+a0, +a1} T.Noted{+b0, +b1}:
      Empty.absurd({T.StatusChanged{a0, a1} == T.Noted{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.StatusChanged{+a0, +a1} T.Edited{+b0, +b1}:
      Empty.absurd({T.StatusChanged{a0, a1} == T.Edited{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.StatusChanged{+a0, +a1} T.Deleted{+b0}:
      Empty.absurd({T.StatusChanged{a0, a1} == T.Deleted{b0} : T.Payload}, false_is_not_true(equality))
    case T.StatusChanged{+a0, +a1} T.SummarySet{+b0, +b1, +b2}:
      Empty.absurd({T.StatusChanged{a0, a1} == T.SummarySet{b0, b1, b2} : T.Payload}, false_is_not_true(equality))
    case T.StatusChanged{+a0, +a1} T.StandupSet{+b0, +b1, +b2}:
      Empty.absurd({T.StatusChanged{a0, a1} == T.StandupSet{b0, b1, b2} : T.Payload}, false_is_not_true(equality))
    case T.StatusChanged{+a0, +a1} T.Opaque{+b0}:
      Empty.absurd({T.StatusChanged{a0, a1} == T.Opaque{b0} : T.Payload}, false_is_not_true(equality))
    case T.Noted{+a0, +a1} T.Created{+b0, +b1, +b2, +b3, +b4, +b5}:
      Empty.absurd({T.Noted{a0, a1} == T.Created{b0, b1, b2, b3, b4, b5} : T.Payload}, false_is_not_true(equality))
    case T.Noted{+a0, +a1} T.StatusChanged{+b0, +b1}:
      Empty.absurd({T.Noted{a0, a1} == T.StatusChanged{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.Noted{+a0, +a1} T.Noted{+b0, +b1}:
      comparison0 = and_true_left(String.eq(a0, b0), String.eq(a1, b1), equality)
      +remaining1 = and_true_right(String.eq(a0, b0), String.eq(a1, b1), equality)
      field0 = string_equality_sound(a0, b0, comparison0)
      field1 = string_equality_sound(a1, b1, remaining1)
      %field0 : {T.Noted{a0, a1} == T.Noted{_, b1} : T.Payload}
      %field1 : {T.Noted{a0, a1} == T.Noted{a0, _} : T.Payload}
      {==}
    case T.Noted{+a0, +a1} T.Edited{+b0, +b1}:
      Empty.absurd({T.Noted{a0, a1} == T.Edited{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.Noted{+a0, +a1} T.Deleted{+b0}:
      Empty.absurd({T.Noted{a0, a1} == T.Deleted{b0} : T.Payload}, false_is_not_true(equality))
    case T.Noted{+a0, +a1} T.SummarySet{+b0, +b1, +b2}:
      Empty.absurd({T.Noted{a0, a1} == T.SummarySet{b0, b1, b2} : T.Payload}, false_is_not_true(equality))
    case T.Noted{+a0, +a1} T.StandupSet{+b0, +b1, +b2}:
      Empty.absurd({T.Noted{a0, a1} == T.StandupSet{b0, b1, b2} : T.Payload}, false_is_not_true(equality))
    case T.Noted{+a0, +a1} T.Opaque{+b0}:
      Empty.absurd({T.Noted{a0, a1} == T.Opaque{b0} : T.Payload}, false_is_not_true(equality))
    case T.Edited{+a0, +a1} T.Created{+b0, +b1, +b2, +b3, +b4, +b5}:
      Empty.absurd({T.Edited{a0, a1} == T.Created{b0, b1, b2, b3, b4, b5} : T.Payload}, false_is_not_true(equality))
    case T.Edited{+a0, +a1} T.StatusChanged{+b0, +b1}:
      Empty.absurd({T.Edited{a0, a1} == T.StatusChanged{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.Edited{+a0, +a1} T.Noted{+b0, +b1}:
      Empty.absurd({T.Edited{a0, a1} == T.Noted{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.Edited{+a0, +a1} T.Edited{+b0, +b1}:
      comparison0 = and_true_left(String.eq(a0, b0), Core.patch_eq(a1, b1), equality)
      +remaining1 = and_true_right(String.eq(a0, b0), Core.patch_eq(a1, b1), equality)
      field0 = string_equality_sound(a0, b0, comparison0)
      field1 = patch_equality_sound(a1, b1, remaining1)
      %field0 : {T.Edited{a0, a1} == T.Edited{_, b1} : T.Payload}
      %field1 : {T.Edited{a0, a1} == T.Edited{a0, _} : T.Payload}
      {==}
    case T.Edited{+a0, +a1} T.Deleted{+b0}:
      Empty.absurd({T.Edited{a0, a1} == T.Deleted{b0} : T.Payload}, false_is_not_true(equality))
    case T.Edited{+a0, +a1} T.SummarySet{+b0, +b1, +b2}:
      Empty.absurd({T.Edited{a0, a1} == T.SummarySet{b0, b1, b2} : T.Payload}, false_is_not_true(equality))
    case T.Edited{+a0, +a1} T.StandupSet{+b0, +b1, +b2}:
      Empty.absurd({T.Edited{a0, a1} == T.StandupSet{b0, b1, b2} : T.Payload}, false_is_not_true(equality))
    case T.Edited{+a0, +a1} T.Opaque{+b0}:
      Empty.absurd({T.Edited{a0, a1} == T.Opaque{b0} : T.Payload}, false_is_not_true(equality))
    case T.Deleted{+a0} T.Created{+b0, +b1, +b2, +b3, +b4, +b5}:
      Empty.absurd({T.Deleted{a0} == T.Created{b0, b1, b2, b3, b4, b5} : T.Payload}, false_is_not_true(equality))
    case T.Deleted{+a0} T.StatusChanged{+b0, +b1}:
      Empty.absurd({T.Deleted{a0} == T.StatusChanged{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.Deleted{+a0} T.Noted{+b0, +b1}:
      Empty.absurd({T.Deleted{a0} == T.Noted{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.Deleted{+a0} T.Edited{+b0, +b1}:
      Empty.absurd({T.Deleted{a0} == T.Edited{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.Deleted{+a0} T.Deleted{+b0}:
      field0 = string_equality_sound(a0, b0, equality)
      %field0 : {T.Deleted{a0} == T.Deleted{_} : T.Payload}
      {==}
    case T.Deleted{+a0} T.SummarySet{+b0, +b1, +b2}:
      Empty.absurd({T.Deleted{a0} == T.SummarySet{b0, b1, b2} : T.Payload}, false_is_not_true(equality))
    case T.Deleted{+a0} T.StandupSet{+b0, +b1, +b2}:
      Empty.absurd({T.Deleted{a0} == T.StandupSet{b0, b1, b2} : T.Payload}, false_is_not_true(equality))
    case T.Deleted{+a0} T.Opaque{+b0}:
      Empty.absurd({T.Deleted{a0} == T.Opaque{b0} : T.Payload}, false_is_not_true(equality))
    case T.SummarySet{+a0, +a1, +a2} T.Created{+b0, +b1, +b2, +b3, +b4, +b5}:
      Empty.absurd({T.SummarySet{a0, a1, a2} == T.Created{b0, b1, b2, b3, b4, b5} : T.Payload}, false_is_not_true(equality))
    case T.SummarySet{+a0, +a1, +a2} T.StatusChanged{+b0, +b1}:
      Empty.absurd({T.SummarySet{a0, a1, a2} == T.StatusChanged{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.SummarySet{+a0, +a1, +a2} T.Noted{+b0, +b1}:
      Empty.absurd({T.SummarySet{a0, a1, a2} == T.Noted{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.SummarySet{+a0, +a1, +a2} T.Edited{+b0, +b1}:
      Empty.absurd({T.SummarySet{a0, a1, a2} == T.Edited{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.SummarySet{+a0, +a1, +a2} T.Deleted{+b0}:
      Empty.absurd({T.SummarySet{a0, a1, a2} == T.Deleted{b0} : T.Payload}, false_is_not_true(equality))
    case T.SummarySet{+a0, +a1, +a2} T.SummarySet{+b0, +b1, +b2}:
      comparison0 = and_true_left(String.eq(a0, b0), Bool.and(String.eq(a1, b1), String.eq(a2, b2)), equality)
      +remaining1 = and_true_right(String.eq(a0, b0), Bool.and(String.eq(a1, b1), String.eq(a2, b2)), equality)
      field0 = string_equality_sound(a0, b0, comparison0)
      comparison1 = and_true_left(String.eq(a1, b1), String.eq(a2, b2), remaining1)
      +remaining2 = and_true_right(String.eq(a1, b1), String.eq(a2, b2), remaining1)
      field1 = string_equality_sound(a1, b1, comparison1)
      field2 = string_equality_sound(a2, b2, remaining2)
      %field0 : {T.SummarySet{a0, a1, a2} == T.SummarySet{_, b1, b2} : T.Payload}
      %field1 : {T.SummarySet{a0, a1, a2} == T.SummarySet{a0, _, b2} : T.Payload}
      %field2 : {T.SummarySet{a0, a1, a2} == T.SummarySet{a0, a1, _} : T.Payload}
      {==}
    case T.SummarySet{+a0, +a1, +a2} T.StandupSet{+b0, +b1, +b2}:
      Empty.absurd({T.SummarySet{a0, a1, a2} == T.StandupSet{b0, b1, b2} : T.Payload}, false_is_not_true(equality))
    case T.SummarySet{+a0, +a1, +a2} T.Opaque{+b0}:
      Empty.absurd({T.SummarySet{a0, a1, a2} == T.Opaque{b0} : T.Payload}, false_is_not_true(equality))
    case T.StandupSet{+a0, +a1, +a2} T.Created{+b0, +b1, +b2, +b3, +b4, +b5}:
      Empty.absurd({T.StandupSet{a0, a1, a2} == T.Created{b0, b1, b2, b3, b4, b5} : T.Payload}, false_is_not_true(equality))
    case T.StandupSet{+a0, +a1, +a2} T.StatusChanged{+b0, +b1}:
      Empty.absurd({T.StandupSet{a0, a1, a2} == T.StatusChanged{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.StandupSet{+a0, +a1, +a2} T.Noted{+b0, +b1}:
      Empty.absurd({T.StandupSet{a0, a1, a2} == T.Noted{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.StandupSet{+a0, +a1, +a2} T.Edited{+b0, +b1}:
      Empty.absurd({T.StandupSet{a0, a1, a2} == T.Edited{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.StandupSet{+a0, +a1, +a2} T.Deleted{+b0}:
      Empty.absurd({T.StandupSet{a0, a1, a2} == T.Deleted{b0} : T.Payload}, false_is_not_true(equality))
    case T.StandupSet{+a0, +a1, +a2} T.SummarySet{+b0, +b1, +b2}:
      Empty.absurd({T.StandupSet{a0, a1, a2} == T.SummarySet{b0, b1, b2} : T.Payload}, false_is_not_true(equality))
    case T.StandupSet{+a0, +a1, +a2} T.StandupSet{+b0, +b1, +b2}:
      comparison0 = and_true_left(String.eq(a0, b0), Bool.and(String.eq(a1, b1), String.eq(a2, b2)), equality)
      +remaining1 = and_true_right(String.eq(a0, b0), Bool.and(String.eq(a1, b1), String.eq(a2, b2)), equality)
      field0 = string_equality_sound(a0, b0, comparison0)
      comparison1 = and_true_left(String.eq(a1, b1), String.eq(a2, b2), remaining1)
      +remaining2 = and_true_right(String.eq(a1, b1), String.eq(a2, b2), remaining1)
      field1 = string_equality_sound(a1, b1, comparison1)
      field2 = string_equality_sound(a2, b2, remaining2)
      %field0 : {T.StandupSet{a0, a1, a2} == T.StandupSet{_, b1, b2} : T.Payload}
      %field1 : {T.StandupSet{a0, a1, a2} == T.StandupSet{a0, _, b2} : T.Payload}
      %field2 : {T.StandupSet{a0, a1, a2} == T.StandupSet{a0, a1, _} : T.Payload}
      {==}
    case T.StandupSet{+a0, +a1, +a2} T.Opaque{+b0}:
      Empty.absurd({T.StandupSet{a0, a1, a2} == T.Opaque{b0} : T.Payload}, false_is_not_true(equality))
    case T.Opaque{+a0} T.Created{+b0, +b1, +b2, +b3, +b4, +b5}:
      Empty.absurd({T.Opaque{a0} == T.Created{b0, b1, b2, b3, b4, b5} : T.Payload}, false_is_not_true(equality))
    case T.Opaque{+a0} T.StatusChanged{+b0, +b1}:
      Empty.absurd({T.Opaque{a0} == T.StatusChanged{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.Opaque{+a0} T.Noted{+b0, +b1}:
      Empty.absurd({T.Opaque{a0} == T.Noted{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.Opaque{+a0} T.Edited{+b0, +b1}:
      Empty.absurd({T.Opaque{a0} == T.Edited{b0, b1} : T.Payload}, false_is_not_true(equality))
    case T.Opaque{+a0} T.Deleted{+b0}:
      Empty.absurd({T.Opaque{a0} == T.Deleted{b0} : T.Payload}, false_is_not_true(equality))
    case T.Opaque{+a0} T.SummarySet{+b0, +b1, +b2}:
      Empty.absurd({T.Opaque{a0} == T.SummarySet{b0, b1, b2} : T.Payload}, false_is_not_true(equality))
    case T.Opaque{+a0} T.StandupSet{+b0, +b1, +b2}:
      Empty.absurd({T.Opaque{a0} == T.StandupSet{b0, b1, b2} : T.Payload}, false_is_not_true(equality))
    case T.Opaque{+a0} T.Opaque{+b0}:
      field0 = string_equality_sound(a0, b0, equality)
      %field0 : {T.Opaque{a0} == T.Opaque{_} : T.Payload}
      {==}

def event_equality_sound(a: T.DomainEvent, b: T.DomainEvent, +equality: {Core.event_eq(a, b) == True{} : Bool}) -> {a == b : T.DomainEvent}:
  match a b:
    case T.Ev{+a0, +a1, +a2, +a3, +a4} T.Ev{+b0, +b1, +b2, +b3, +b4}:
      comparison0 = and_true_left(String.eq(a0, b0), Bool.and(String.eq(a1, b1), Bool.and(String.eq(a2, b2), Bool.and(Core.payload_eq(a3, b3), String.eq(a4, b4)))), equality)
      +remaining1 = and_true_right(String.eq(a0, b0), Bool.and(String.eq(a1, b1), Bool.and(String.eq(a2, b2), Bool.and(Core.payload_eq(a3, b3), String.eq(a4, b4)))), equality)
      field0 = string_equality_sound(a0, b0, comparison0)
      comparison1 = and_true_left(String.eq(a1, b1), Bool.and(String.eq(a2, b2), Bool.and(Core.payload_eq(a3, b3), String.eq(a4, b4))), remaining1)
      +remaining2 = and_true_right(String.eq(a1, b1), Bool.and(String.eq(a2, b2), Bool.and(Core.payload_eq(a3, b3), String.eq(a4, b4))), remaining1)
      field1 = string_equality_sound(a1, b1, comparison1)
      comparison2 = and_true_left(String.eq(a2, b2), Bool.and(Core.payload_eq(a3, b3), String.eq(a4, b4)), remaining2)
      +remaining3 = and_true_right(String.eq(a2, b2), Bool.and(Core.payload_eq(a3, b3), String.eq(a4, b4)), remaining2)
      field2 = string_equality_sound(a2, b2, comparison2)
      comparison3 = and_true_left(Core.payload_eq(a3, b3), String.eq(a4, b4), remaining3)
      +remaining4 = and_true_right(Core.payload_eq(a3, b3), String.eq(a4, b4), remaining3)
      field3 = payload_equality_sound(a3, b3, comparison3)
      field4 = string_equality_sound(a4, b4, remaining4)
      %field0 : {T.Ev{a0, a1, a2, a3, a4} == T.Ev{_, b1, b2, b3, b4} : T.DomainEvent}
      %field1 : {T.Ev{a0, a1, a2, a3, a4} == T.Ev{a0, _, b2, b3, b4} : T.DomainEvent}
      %field2 : {T.Ev{a0, a1, a2, a3, a4} == T.Ev{a0, a1, _, b3, b4} : T.DomainEvent}
      %field3 : {T.Ev{a0, a1, a2, a3, a4} == T.Ev{a0, a1, a2, _, b4} : T.DomainEvent}
      %field4 : {T.Ev{a0, a1, a2, a3, a4} == T.Ev{a0, a1, a2, a3, _} : T.DomainEvent}
      {==}

def string_propositional_equality_detected(+a: String, +b: String, equality: {a == b : String}) -> {String.eq(a, b) == True{} : Bool}:
  Equal.trans(Bool, String.eq(a, b), String.eq(b, b), True{},
    Equal.cong(String, Bool, left => String.eq(left, b), a, b, equality), string_equality_reflexive(b))

def event_inequality_is_detected(+a: T.DomainEvent, +b: T.DomainEvent, different: {a != b : T.DomainEvent}) -> {Core.event_eq(a, b) == False{} : Bool}:
  bool_not_true_is_false(Core.event_eq(a, b),
    same => different(event_equality_sound(a, b, same)))
