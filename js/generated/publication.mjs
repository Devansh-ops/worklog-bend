function word_to_u32(w) {
  let x = 0;
  for (let i = 0; w.$ === "WCon"; i++) {
    x |= Number(w.head) << i;
    w = w.tail;
  }
  return x >>> 0;
}

function u32_to_word(x) {
  let w = {$: "WNil"};
  for (let i = 31; i >= 0; i--) {
    w = {$: "WCon", head: ((x >>> i) & 1) === 1, tail: w};
  }
  return w;
}

function cmp_new(a, b) {
  return {$: a < b ? "LT" : a === b ? "EQ" : "GT"};
}

function tup_new(a, b) {
  return {$: "Tuple", fst: a, snd: b};
}

function nat_divmod(a, b) {
  return tup_new(b && Math.trunc(a / b), b ? a % b : a);
}

function nat_chk(n) {
  if (n > 281474976710655) {
    throw "bend: a Nat past the largest immediate 2^48-1";
  }
  return n;
}

function nat_in(n) {
  if (!Number.isInteger(n) || n < 0 || n > 2 ** 53) {
    throw "bend: expected a Nat host number: an integer from 0 to 2^53";
  }
  return n;
}

function f32_show(x) {
  let s = "nan";
  for (let p = 1; x === x && p <= 9 && f32_round(s) !== x; p += 1) {
    s = String(Number(x.toExponential(p - 1)));
  }
  return (Object.is(x, -0) ? "-0" : s).replace("Infinity", "inf");
}

function f32_bits(x) {
  return new Uint32Array(new Float32Array([x]).buffer)[0];
}

function f32_from_bits(u) {
  return new Float32Array(new Uint32Array([u]).buffer)[0];
}

function f32_read(s) {
  const re = /^[\t\n\v\f\r ]*[+-]?((\d+(?:\.\d*)?|\.\d+)(e[+-]?\d+)?|inf(inity)?|nan)$/i;
  return re.test(s) ? {$: "Some", value: f32_round(
    s.replace(/inf\w*/i, "Infinity"))} : {$: "None"};
}

const f32_round = function f32_round(s) {
  const d = Number(s), a = Math.abs(d), f = Math.fround(a), g = 2 * a - Math.min(f, 340282366920938500000000000000000000000);
  if (g === f || Math.fround(g) !== g || g === 1 / 0)
    return Math.sign(d) * f;
  let k = 0;
  while (a * 2 ** k % 1 !== 0)
    k += 1;
  const [, i, r, e] = /(\d*)\.?(\d*)(?:e([+-]?\d+))?$/i.exec(s), n = Number(e ?? 0) - r.length, x = BigInt(i + r) * 2n ** BigInt(k) * 10n ** BigInt(Math.max(n, 0)), y = BigInt(a * 2 ** k) * 10n ** BigInt(Math.max(-n, 0));
  return Math.sign(d) * (x === y || x > y !== g > f ? f : g);
};

const char_new = function char_new(c) {
  return c < 55296 || c >= 57344 && c <= 1114111 ? String.fromCodePoint(c) : String.fromCharCode(56320, c >>> 22, c >>> 11 & 2047, c & 2047);
};

function char_len(s, at = 0) {
  const c = s.codePointAt(at);
  return c === 0xDC00 ? 4 : c > 0xFFFF ? 2 : 1;
}

function char_code(s) {
  return s.length < 4 ? s.codePointAt(0)
    : (s.charCodeAt(1) << 22 | s.charCodeAt(2) << 11 | s.charCodeAt(3)) >>> 0;
}

function string_contains(s, p) {
  // A match starts at a Char, not inside a packed U32 code.
  for (let at = 0; at <= s.length; at += char_len(s, at)) {
    if (s.startsWith(p, at)) {
      return true;
    }
  }
  return false;
}

function str_out(s) {
  return s.replace(/\uDC00[^]{3}/gu, "\uFFFD");
}

function str_in(s) {
  return s.replace(/\p{Cs}/gu, "\uFFFD");
}

// Array
// =====

function array_new(d, v, lgs) {
  if (d > 31 - lgs) {
    throw "bend: an array past the deepest block class 31 (depth + log2 words per cell)";
  }
  return Array(2 ** d).fill(v);
}

function array_node(a, b) {
  if (a.length !== b.length) {
    throw "bend: runtime fail-stop";
  }
  return a.concat(b);
}

function array_rmw(a, i, f) {
  const old = a[i %= a.length];
  a[i] = f(old);
  return tup_new(a, old);
}

// Run
// ===

function run_tail(f, x) {
  return {$: "$JMP", f: f.j?.f === f ? f.j : f, x};
}

function run_clo(j) {
  const f = (x) => run_loop(j(x));
  f.j = j;
  j.f = f;
  return f;
}

function run_loop(r) {
  while (r !== null && typeof r === "object" && r.$ === "$JMP") {
    r = r.f(r.x);
  }
  return r;
}

function run_lib(f, n) {
  return (...a) => a.length < n ? run_lib((...b) => f(...a, ...b), n - a.length)
    : run_loop(f(...a));
}

// Effect
// ======

const $0eff = Object.create(null);
const io_file_append = new Set();

function io_eff(k, run) {
  if (arguments.length > 2) {
    throw new Error("bend: " + k + " takes no need: an effect that waits parks itself");
  }
  if (k in $0eff) {
    throw new Error("bend: two effects register " + k);
  }
  $0eff[k] = run;
}
// Program
// =======

function $Core_status_eq(_a_0, _b_0) {
  if (_a_0.$ === "SBacklog") {
    if (_b_0.$ === "SBacklog") {
      return true;
    } else {
      return false;
    }
  } else if (_a_0.$ === "STodo") {
    if (_b_0.$ === "STodo") {
      return true;
    } else {
      return false;
    }
  } else if (_a_0.$ === "SProgress") {
    if (_b_0.$ === "SProgress") {
      return true;
    } else {
      return false;
    }
  } else if (_a_0.$ === "SBlocked") {
    if (_b_0.$ === "SBlocked") {
      return true;
    } else {
      return false;
    }
  } else if (_a_0.$ === "SReview") {
    if (_b_0.$ === "SReview") {
      return true;
    } else {
      return false;
    }
  } else {
    if (_b_0.$ === "SDone") {
      return true;
    } else {
      return false;
    }
  }
}

function $Core_priority_eq(_a_0, _b_0) {
  if (_a_0.$ === "PLow") {
    if (_b_0.$ === "PLow") {
      return true;
    } else {
      return false;
    }
  } else if (_a_0.$ === "PNormal") {
    if (_b_0.$ === "PNormal") {
      return true;
    } else {
      return false;
    }
  } else if (_a_0.$ === "PHigh") {
    if (_b_0.$ === "PHigh") {
      return true;
    } else {
      return false;
    }
  } else {
    if (_b_0.$ === "PUrgent") {
      return true;
    } else {
      return false;
    }
  }
}

function $Core_bool_eq(_a_0, _b_0) {
  return $Cmp_is_eq($$Bool_cmp(_a_0, _b_0));
}

function $Core_strings_eq(_xs_0, _ys_0) {
  if (_xs_0.$ === "Nil") {
    if (_ys_0.$ === "Nil") {
      return true;
    } else {
      return false;
    }
  } else {
    const _x_0 = _xs_0["head"];
    const _xt_0 = _xs_0["tail"];
    if (_ys_0.$ === "Con") {
      const _y_0 = _ys_0["head"];
      const _yt_0 = _ys_0["tail"];
      return $Bool_and((_x_0 === _y_0), $$Core_strings_eq(_xt_0, _yt_0));
    } else {
      return false;
    }
  }
}

function $Core_optional_string_eq(_a_0, _b_0) {
  if (_a_0.$ === "None") {
    if (_b_0.$ === "None") {
      return true;
    } else {
      return false;
    }
  } else {
    const _x_0 = _a_0["value"];
    if (_b_0.$ === "Some") {
      const _y_0 = _b_0["value"];
      return (_x_0 === _y_0);
    } else {
      return false;
    }
  }
}

function $Core_optional_status_eq(_a_0, _b_0) {
  if (_a_0.$ === "None") {
    if (_b_0.$ === "None") {
      return true;
    } else {
      return false;
    }
  } else {
    const _x_0 = _a_0["value"];
    if (_b_0.$ === "Some") {
      const _y_0 = _b_0["value"];
      return $Core_status_eq(_x_0, _y_0);
    } else {
      return false;
    }
  }
}

function $Core_optional_priority_eq(_a_0, _b_0) {
  if (_a_0.$ === "None") {
    if (_b_0.$ === "None") {
      return true;
    } else {
      return false;
    }
  } else {
    const _x_0 = _a_0["value"];
    if (_b_0.$ === "Some") {
      const _y_0 = _b_0["value"];
      return $Core_priority_eq(_x_0, _y_0);
    } else {
      return false;
    }
  }
}

function $Core_optional_strings_eq(_a_0, _b_0) {
  if (_a_0.$ === "None") {
    if (_b_0.$ === "None") {
      return true;
    } else {
      return false;
    }
  } else {
    const _x_0 = _a_0["value"];
    if (_b_0.$ === "Some") {
      const _y_0 = _b_0["value"];
      return $Core_strings_eq(_x_0, _y_0);
    } else {
      return false;
    }
  }
}

function $Core_optional_bool_eq(_a_0, _b_0) {
  if (_a_0.$ === "None") {
    if (_b_0.$ === "None") {
      return true;
    } else {
      return false;
    }
  } else {
    const _x_0 = _a_0["value"];
    if (_b_0.$ === "Some") {
      const _y_0 = _b_0["value"];
      return $Core_bool_eq(_x_0, _y_0);
    } else {
      return false;
    }
  }
}

function $Core_patch_eq(_a_0, _b_0) {
  const _at_0 = _a_0["title"];
  const _ast_0 = _a_0["status"];
  const _ap_0 = _a_0["priority"];
  const _ag_0 = _a_0["tags"];
  const _av_0 = _a_0["private"];
  const _bt_0 = _b_0["title"];
  const _bst_0 = _b_0["status"];
  const _bp_0 = _b_0["priority"];
  const _bg_0 = _b_0["tags"];
  const _bv_0 = _b_0["private"];
  return $Bool_and($$Core_optional_string_eq(_at_0, _bt_0), $$Bool_and($$Core_optional_status_eq(_ast_0, _bst_0), $$Bool_and($$Core_optional_priority_eq(_ap_0, _bp_0), $$Bool_and($$Core_optional_strings_eq(_ag_0, _bg_0), $$Core_optional_bool_eq(_av_0, _bv_0)))));
}

function $Core_payload_eq(_a_0, _b_0) {
  if (_a_0.$ === "Created") {
    const _ai_0 = _a_0["taskId"];
    const _at_0 = _a_0["title"];
    const _ast_0 = _a_0["status"];
    const _ap_0 = _a_0["priority"];
    const _ag_0 = _a_0["tags"];
    const _av_0 = _a_0["private"];
    if (_b_0.$ === "Created") {
      const _bi_0 = _b_0["taskId"];
      const _bt_0 = _b_0["title"];
      const _bst_0 = _b_0["status"];
      const _bp_0 = _b_0["priority"];
      const _bg_0 = _b_0["tags"];
      const _bv_0 = _b_0["private"];
      return $Bool_and((_ai_0 === _bi_0), $$Bool_and((_at_0 === _bt_0), $$Bool_and($$Core_status_eq(_ast_0, _bst_0), $$Bool_and($$Core_priority_eq(_ap_0, _bp_0), $$Bool_and($$Core_strings_eq(_ag_0, _bg_0), $$Core_bool_eq(_av_0, _bv_0))))));
    } else {
      return false;
    }
  } else if (_a_0.$ === "StatusChanged") {
    const _ai_1 = _a_0["taskId"];
    const _ast_1 = _a_0["status"];
    if (_b_0.$ === "StatusChanged") {
      const _bi_1 = _b_0["taskId"];
      const _bst_1 = _b_0["status"];
      return $Bool_and((_ai_1 === _bi_1), $$Core_status_eq(_ast_1, _bst_1));
    } else {
      return false;
    }
  } else if (_a_0.$ === "Noted") {
    const _ai_2 = _a_0["taskId"];
    const _at_1 = _a_0["text"];
    if (_b_0.$ === "Noted") {
      const _bi_2 = _b_0["taskId"];
      const _bt_1 = _b_0["text"];
      return $Bool_and((_ai_2 === _bi_2), (_at_1 === _bt_1));
    } else {
      return false;
    }
  } else if (_a_0.$ === "Edited") {
    const _ai_3 = _a_0["taskId"];
    const _ap_1 = _a_0["patch"];
    if (_b_0.$ === "Edited") {
      const _bi_3 = _b_0["taskId"];
      const _bp_1 = _b_0["patch"];
      return $Bool_and((_ai_3 === _bi_3), $$Core_patch_eq(_ap_1, _bp_1));
    } else {
      return false;
    }
  } else if (_a_0.$ === "Deleted") {
    const _ai_4 = _a_0["taskId"];
    if (_b_0.$ === "Deleted") {
      const _bi_4 = _b_0["taskId"];
      return (_ai_4 === _bi_4);
    } else {
      return false;
    }
  } else if (_a_0.$ === "SummarySet") {
    const _ad_0 = _a_0["date"];
    const _ak_0 = _a_0["kind"];
    const _ab_0 = _a_0["body"];
    if (_b_0.$ === "SummarySet") {
      const _bd_0 = _b_0["date"];
      const _bk_0 = _b_0["kind"];
      const _bb_0 = _b_0["body"];
      return $Bool_and((_ad_0 === _bd_0), $$Bool_and((_ak_0 === _bk_0), (_ab_0 === _bb_0)));
    } else {
      return false;
    }
  } else if (_a_0.$ === "StandupSet") {
    const _ad_1 = _a_0["date"];
    const _ak_1 = _a_0["kind"];
    const _ab_1 = _a_0["text"];
    if (_b_0.$ === "StandupSet") {
      const _bd_1 = _b_0["date"];
      const _bk_1 = _b_0["kind"];
      const _bb_1 = _b_0["text"];
      return $Bool_and((_ad_1 === _bd_1), $$Bool_and((_ak_1 === _bk_1), (_ab_1 === _bb_1)));
    } else {
      return false;
    }
  } else {
    const _ak_2 = _a_0["kind"];
    if (_b_0.$ === "Opaque") {
      const _bk_2 = _b_0["kind"];
      return (_ak_2 === _bk_2);
    } else {
      return false;
    }
  }
}

function $Core_event_id(_e_0) {
  const _id_0 = _e_0["id"];
  return _id_0;
}

function $Core_event_eq(_a_0, _b_0) {
  const _ai_0 = _a_0["id"];
  const _at_0 = _a_0["ts"];
  const _ad_0 = _a_0["day"];
  const _ap_0 = _a_0["payload"];
  const _ac_0 = _a_0["canonical"];
  const _bi_0 = _b_0["id"];
  const _bt_0 = _b_0["ts"];
  const _bd_0 = _b_0["day"];
  const _bp_0 = _b_0["payload"];
  const _bc_0 = _b_0["canonical"];
  return $Bool_and((_ai_0 === _bi_0), $$Bool_and((_at_0 === _bt_0), $$Bool_and((_ad_0 === _bd_0), $$Bool_and($$Core_payload_eq(_ap_0, _bp_0), (_ac_0 === _bc_0)))));
}

function $Core_event_le_tie(_ai_0, _bi_0, _at_0, _bt_0, _same_0) {
  if (_same_0) {
    return $String_is_le(_ai_0, _bi_0);
  } else {
    return $String_is_le(_at_0, _bt_0);
  }
}

function $Core_event_le(_a_0, _b_0) {
  const _ai_0 = _a_0["id"];
  const _at_0 = _a_0["ts"];
  const _bi_0 = _b_0["id"];
  const _bt_0 = _b_0["ts"];
  return $Core_event_le_tie(_ai_0, _bi_0, _at_0, _bt_0, (_at_0 === _bt_0));
}

function $Core_ids_contains(_xs_0, _id_0) {
  if (_xs_0.$ === "Nil") {
    return false;
  } else {
    const _h_0 = _xs_0["head"];
    const _t_0 = _xs_0["tail"];
    const _x_0 = $$Core_event_id(_h_0);
    const _x_1 = (_x_0 === _id_0);
    const _x_2 = $$Core_ids_contains(_t_0, _id_0);
    return (_x_1 || _x_2);
  }
}

function $Core_unique_put(_e_0, _xs_0, _exists_0) {
  if (_exists_0) {
    return _xs_0;
  } else {
    return {$: "Con", "head": _e_0, "tail": _xs_0};
  }
}

function $Core_event_id_le(_a_0, _b_0) {
  return $String_is_le($$Core_event_id(_a_0), $$Core_event_id(_b_0));
}

function $Core_scan_ids($0, $1, $2) {
  for (;;) {
    {
      const _fuel_0 = $0;
      const _acc_0 = $1;
      const _previous_0 = $2;
      if (_fuel_0.$ === "Nil") {
        return {$: "Merged", "events": $$List_sort_0(_acc_0)};
      } else {
        const _h_0 = _fuel_0["head"];
        const _t_0 = _fuel_0["tail"];
        if (_previous_0.$ === "None") {
          $0 = _t_0;
          $1 = {$: "Con", "head": _h_0, "tail": _acc_0};
          $2 = {$: "Some", "value": _h_0};
          continue;
        } else {
          const _p_0 = _previous_0["value"];
          const _x_0 = $$Core_event_id(_h_0);
          const _x_1 = $$Core_event_id(_p_0);
          const _same_0 = (_x_0 === _x_1);
          return $Bool_pick($$Bool_and(_same_0, $$Bool_not($$Core_event_eq(_h_0, _p_0))), {$: "EventConflict", "id": $$Core_event_id(_h_0)}, $$Core_scan_ids(_t_0, $$Core_unique_put(_h_0, _acc_0, _same_0), {$: "Some", "value": _h_0}));
        }
      }
    }
  }
}

function $Core_merge(_left_0, _right_0) {
  return $Core_scan_ids($$List_sort_1($$List_append(_left_0, _right_0)), {$: "Nil"}, {$: "None"});
}

function $Core_completion(_status_0, _instant_0) {
  if (_status_0.$ === "SDone") {
    return {$: "Some", "value": _instant_0};
  } else {
    return {$: "None"};
  }
}

function $Core_eligible(_task_0) {
  const _private_0 = _task_0["private"];
  const _deleted_0 = _task_0["deleted"];
  return $Bool_and($$Bool_not(_private_0), $$Bool_not(_deleted_0));
}

function $Core_chosen_notes(_notes_0, _sendNotes_0) {
  if (!_sendNotes_0) {
    return {$: "Nil"};
  } else {
    return _notes_0;
  }
}

function $Core_project(_task_0, _sendNotes_0) {
  const _id_0 = _task_0["id"];
  const _title_0 = _task_0["title"];
  const _status_0 = _task_0["status"];
  const _priority_0 = _task_0["priority"];
  const _tags_0 = _task_0["tags"];
  const _notes_0 = _task_0["notes"];
  return {$: "ContextTask", "id": _id_0, "title": _title_0, "status": _status_0, "priority": _priority_0, "tags": _tags_0, "notes": $$Core_chosen_notes(_notes_0, _sendNotes_0)};
}

function $Core_context_notes(_task_0) {
  const _notes_0 = _task_0["notes"];
  return _notes_0;
}

function $Core_task_id(_task_0) {
  const _id_0 = _task_0["id"];
  return _id_0;
}

function $Core_task_deleted(_task_0) {
  const _deleted_0 = _task_0["deleted"];
  return _deleted_0;
}

function $Core_task_find(_tasks_0, _id_0) {
  if (_tasks_0.$ === "Nil") {
    return {$: "None"};
  } else {
    const _h_0 = _tasks_0["head"];
    const _t_0 = _tasks_0["tail"];
    const _x_0 = $$Core_task_id(_h_0);
    return $Bool_pick((_x_0 === _id_0), {$: "Some", "value": _h_0}, $$Core_task_find(_t_0, _id_0));
  }
}

function $Core_put_task(_tasks_0, _task_0) {
  if (_tasks_0.$ === "Nil") {
    return {$: "Con", "head": _task_0, "tail": {$: "Nil"}};
  } else {
    const _h_0 = _tasks_0["head"];
    const _t_0 = _tasks_0["tail"];
    const _x_0 = $$Core_task_id(_h_0);
    const _x_1 = $$Core_task_id(_task_0);
    return $Bool_pick((_x_0 === _x_1), {$: "Con", "head": _task_0, "tail": _t_0}, {$: "Con", "head": _h_0, "tail": $$Core_put_task(_t_0, _task_0)});
  }
}

function $Core_record_key_equal(_a_0, _b_0) {
  const _ad_0 = _a_0["date"];
  const _ak_0 = _a_0["kind"];
  const _bd_0 = _b_0["date"];
  const _bk_0 = _b_0["kind"];
  return $Bool_and((_ad_0 === _bd_0), (_ak_0 === _bk_0));
}

function $Core_put_record(_records_0, _record_0) {
  if (_records_0.$ === "Nil") {
    return {$: "Con", "head": _record_0, "tail": {$: "Nil"}};
  } else {
    const _h_0 = _records_0["head"];
    const _t_0 = _records_0["tail"];
    return $Bool_pick($$Core_record_key_equal(_h_0, _record_0), {$: "Con", "head": _record_0, "tail": _t_0}, {$: "Con", "head": _h_0, "tail": $$Core_put_record(_t_0, _record_0)});
  }
}

function $Core_patch_completion(_change_0, _instant_0, _previous_0) {
  if (_change_0.$ === "None") {
    return _previous_0;
  } else {
    const _s_0 = _change_0["value"];
    return $Core_completion(_s_0, _instant_0);
  }
}

function $Core_edit_task(_task_0, _patch_0, _instant_0) {
  const _id_0 = _task_0["id"];
  const _title_0 = _task_0["title"];
  const _status_0 = _task_0["status"];
  const _priority_0 = _task_0["priority"];
  const _tags_0 = _task_0["tags"];
  const _private_0 = _task_0["private"];
  const _deleted_0 = _task_0["deleted"];
  const _created_0 = _task_0["created"];
  const _completed_0 = _task_0["completed"];
  const _notes_0 = _task_0["notes"];
  const _pt_0 = _patch_0["title"];
  const _ps_0 = _patch_0["status"];
  const _pp_0 = _patch_0["priority"];
  const _pg_0 = _patch_0["tags"];
  const _pv_0 = _patch_0["private"];
  return {$: "Task", "id": _id_0, "title": $$Maybe_default(_pt_0, _title_0), "status": $$Maybe_default(_ps_0, _status_0), "priority": $$Maybe_default(_pp_0, _priority_0), "tags": $$Maybe_default(_pg_0, _tags_0), "private": $$Maybe_default(_pv_0, _private_0), "deleted": _deleted_0, "created": _created_0, "updated": _instant_0, "completed": $$Core_patch_completion(_ps_0, _instant_0, _completed_0), "notes": _notes_0};
}

function $Core_note_task(_task_0, _note_0, _instant_0) {
  const _id_0 = _task_0["id"];
  const _title_0 = _task_0["title"];
  const _status_0 = _task_0["status"];
  const _priority_0 = _task_0["priority"];
  const _tags_0 = _task_0["tags"];
  const _private_0 = _task_0["private"];
  const _deleted_0 = _task_0["deleted"];
  const _created_0 = _task_0["created"];
  const _completed_0 = _task_0["completed"];
  const _notes_0 = _task_0["notes"];
  return {$: "Task", "id": _id_0, "title": _title_0, "status": _status_0, "priority": _priority_0, "tags": _tags_0, "private": _private_0, "deleted": _deleted_0, "created": _created_0, "updated": _instant_0, "completed": _completed_0, "notes": $$List_append(_notes_0, {$: "Con", "head": _note_0, "tail": {$: "Nil"}})};
}

function $Core_delete_task(_task_0, _instant_0) {
  const _id_0 = _task_0["id"];
  const _title_0 = _task_0["title"];
  const _status_0 = _task_0["status"];
  const _priority_0 = _task_0["priority"];
  const _tags_0 = _task_0["tags"];
  const _private_0 = _task_0["private"];
  const _created_0 = _task_0["created"];
  const _completed_0 = _task_0["completed"];
  const _notes_0 = _task_0["notes"];
  return {$: "Task", "id": _id_0, "title": _title_0, "status": _status_0, "priority": _priority_0, "tags": _tags_0, "private": _private_0, "deleted": true, "created": _created_0, "updated": _instant_0, "completed": _completed_0, "notes": _notes_0};
}

function $Core_apply_payload(_task_0, _payload_0, _id_0, _instant_0) {
  if (_payload_0.$ === "StatusChanged") {
    const _status_0 = _payload_0["status"];
    return $Core_edit_task(_task_0, {$: "Patch", "title": {$: "None"}, "status": {$: "Some", "value": _status_0}, "priority": {$: "None"}, "tags": {$: "None"}, "private": {$: "None"}}, _instant_0);
  } else if (_payload_0.$ === "Noted") {
    const _text_0 = _payload_0["text"];
    return $Core_note_task(_task_0, {$: "Note", "id": _id_0, "ts": _instant_0, "text": _text_0}, _instant_0);
  } else if (_payload_0.$ === "Edited") {
    const _patch_0 = _payload_0["patch"];
    return $Core_edit_task(_task_0, _patch_0, _instant_0);
  } else if (_payload_0.$ === "Deleted") {
    return $Core_delete_task(_task_0, _instant_0);
  } else {
    return _task_0;
  }
}

function $Core_empty_state() {
  return {$: "State", "tasks": {$: "Nil"}, "summaries": {$: "Nil"}, "reports": {$: "Nil"}, "diagnostics": {$: "Nil"}, "complete": true};
}

function $Core_diagnostic(_state_0, _issue_0) {
  const _tasks_0 = _state_0["tasks"];
  const _summaries_0 = _state_0["summaries"];
  const _reports_0 = _state_0["reports"];
  const _issues_0 = _state_0["diagnostics"];
  return {$: "State", "tasks": _tasks_0, "summaries": _summaries_0, "reports": _reports_0, "diagnostics": $$List_append(_issues_0, {$: "Con", "head": _issue_0, "tail": {$: "Nil"}}), "complete": false};
}

function $Core_state_put(_state_0, _task_0) {
  const _tasks_0 = _state_0["tasks"];
  const _summaries_0 = _state_0["summaries"];
  const _reports_0 = _state_0["reports"];
  const _issues_0 = _state_0["diagnostics"];
  const _complete_0 = _state_0["complete"];
  return {$: "State", "tasks": $$Core_put_task(_tasks_0, _task_0), "summaries": _summaries_0, "reports": _reports_0, "diagnostics": _issues_0, "complete": _complete_0};
}

function $Core_state_task(_state_0, _id_0) {
  const _tasks_0 = _state_0["tasks"];
  return $Core_task_find(_tasks_0, _id_0);
}

function $Core_create_found(_state_0, _task_0, _eventId_0, _taskId_0, _previous_0) {
  if (_previous_0.$ === "None") {
    return $Core_state_put(_state_0, _task_0);
  } else {
    return $Core_diagnostic(_state_0, {$: "DuplicateCreate", "eventId": _eventId_0, "taskId": _taskId_0});
  }
}

function $Core_update_live(_state_0, _task_0, _payload_0, _id_0, _instant_0, _taskId_0, _deleted_0) {
  if (!_deleted_0) {
    return $Core_state_put(_state_0, $$Core_apply_payload(_task_0, _payload_0, _id_0, _instant_0));
  } else {
    return $Core_diagnostic(_state_0, {$: "AfterDelete", "eventId": _id_0, "taskId": _taskId_0});
  }
}

function $Core_update_found(_state_0, _payload_0, _id_0, _instant_0, _taskId_0, _found_0) {
  if (_found_0.$ === "None") {
    return $Core_diagnostic(_state_0, {$: "MissingTask", "eventId": _id_0, "taskId": _taskId_0});
  } else {
    const _task_0 = _found_0["value"];
    return $Core_update_live(_state_0, _task_0, _payload_0, _id_0, _instant_0, _taskId_0, $$Core_task_deleted(_task_0));
  }
}

function $Core_update_existing(_state_0, _payload_0, _id_0, _instant_0, _taskId_0) {
  return $Core_update_found(_state_0, _payload_0, _id_0, _instant_0, _taskId_0, $$Core_state_task(_state_0, _taskId_0));
}

function $Core_apply_summary(_state_0, _record_0) {
  const _tasks_0 = _state_0["tasks"];
  const _summaries_0 = _state_0["summaries"];
  const _reports_0 = _state_0["reports"];
  const _issues_0 = _state_0["diagnostics"];
  const _complete_0 = _state_0["complete"];
  return {$: "State", "tasks": _tasks_0, "summaries": $$Core_put_record(_summaries_0, _record_0), "reports": _reports_0, "diagnostics": _issues_0, "complete": _complete_0};
}

function $Core_apply_report(_state_0, _record_0) {
  const _tasks_0 = _state_0["tasks"];
  const _summaries_0 = _state_0["summaries"];
  const _reports_0 = _state_0["reports"];
  const _issues_0 = _state_0["diagnostics"];
  const _complete_0 = _state_0["complete"];
  return {$: "State", "tasks": _tasks_0, "summaries": _summaries_0, "reports": $$Core_put_record(_reports_0, _record_0), "diagnostics": _issues_0, "complete": _complete_0};
}

function $Core_apply_event(_state_0, _event_0) {
  const _id_0 = _event_0["id"];
  const _ts_0 = _event_0["ts"];
  const _t_0 = _event_0["payload"];
  if (_t_0.$ === "Created") {
    const _taskId_0 = _t_0["taskId"];
    const _title_0 = _t_0["title"];
    const _status_0 = _t_0["status"];
    const _priority_0 = _t_0["priority"];
    const _tags_0 = _t_0["tags"];
    const _private_0 = _t_0["private"];
    return $Core_create_found(_state_0, {$: "Task", "id": _taskId_0, "title": _title_0, "status": _status_0, "priority": _priority_0, "tags": _tags_0, "private": _private_0, "deleted": false, "created": _ts_0, "updated": _ts_0, "completed": $$Core_completion(_status_0, _ts_0), "notes": {$: "Nil"}}, _id_0, _taskId_0, $$Core_state_task(_state_0, _taskId_0));
  } else if (_t_0.$ === "StatusChanged") {
    const _taskId_1 = _t_0["taskId"];
    const _status_1 = _t_0["status"];
    return $Core_update_existing(_state_0, {$: "StatusChanged", "taskId": _taskId_1, "status": _status_1}, _id_0, _ts_0, _taskId_1);
  } else if (_t_0.$ === "Noted") {
    const _taskId_2 = _t_0["taskId"];
    const _text_0 = _t_0["text"];
    return $Core_update_existing(_state_0, {$: "Noted", "taskId": _taskId_2, "text": _text_0}, _id_0, _ts_0, _taskId_2);
  } else if (_t_0.$ === "Edited") {
    const _taskId_3 = _t_0["taskId"];
    const _patch_0 = _t_0["patch"];
    return $Core_update_existing(_state_0, {$: "Edited", "taskId": _taskId_3, "patch": _patch_0}, _id_0, _ts_0, _taskId_3);
  } else if (_t_0.$ === "Deleted") {
    const _taskId_4 = _t_0["taskId"];
    return $Core_update_existing(_state_0, {$: "Deleted", "taskId": _taskId_4}, _id_0, _ts_0, _taskId_4);
  } else if (_t_0.$ === "SummarySet") {
    const _date_0 = _t_0["date"];
    const _kind_0 = _t_0["kind"];
    const _body_0 = _t_0["body"];
    return $Core_apply_summary(_state_0, {$: "Recorded", "id": _id_0, "ts": _ts_0, "date": _date_0, "kind": _kind_0, "body": _body_0});
  } else if (_t_0.$ === "StandupSet") {
    const _date_1 = _t_0["date"];
    const _kind_1 = _t_0["kind"];
    const _text_1 = _t_0["text"];
    return $Core_apply_report(_state_0, {$: "Recorded", "id": _id_0, "ts": _ts_0, "date": _date_1, "kind": _kind_1, "body": _text_1});
  } else {
    const _kind_2 = _t_0["kind"];
    return $Core_diagnostic(_state_0, {$: "Unsupported", "eventId": _id_0, "kind": _kind_2});
  }
}

function $Core_fold_sorted($0, $1) {
  for (;;) {
    {
      const _events_0 = $0;
      const _state_0 = $1;
      if (_events_0.$ === "Nil") {
        return _state_0;
      } else {
        const _h_0 = _events_0["head"];
        const _t_0 = _events_0["tail"];
        $0 = _t_0;
        $1 = $$Core_apply_event(_state_0, _h_0);
        continue;
      }
    }
  }
}

function $Core_replay_merged(_result_0) {
  if (_result_0.$ === "EventConflict") {
    const _id_0 = _result_0["id"];
    return {$: "ReplayConflict", "id": _id_0};
  } else {
    const _events_0 = _result_0["events"];
    return {$: "Replayed", "state": $$Core_fold_sorted(_events_0, $$Core_empty_state())};
  }
}

function $Core_replay(_events_0) {
  return $Core_replay_merged($$Core_merge(_events_0, {$: "Nil"}));
}

function $Core_reconcile(_covered_0, _incoming_0) {
  return $Core_replay_merged($$Core_merge(_covered_0, _incoming_0));
}

function $Core_complete(_state_0) {
  const _complete_0 = _state_0["complete"];
  return _complete_0;
}

function $Core_context_put(_task_0, _rest_0, _sendNotes_0, _keep_0) {
  if (!_keep_0) {
    return _rest_0;
  } else {
    return {$: "Con", "head": $$Core_project(_task_0, _sendNotes_0), "tail": _rest_0};
  }
}

function $Core_context_tasks(_tasks_0, _sendNotes_0) {
  if (_tasks_0.$ === "Nil") {
    return {$: "Nil"};
  } else {
    const _h_0 = _tasks_0["head"];
    const _t_0 = _tasks_0["tail"];
    return $Core_context_put(_h_0, $$Core_context_tasks(_t_0, _sendNotes_0), _sendNotes_0, $$Core_eligible(_h_0));
  }
}

function $Core_context_state(_safe_0, _state_0, _sendNotes_0) {
  if (!_safe_0) {
    return {$: "Nil"};
  } else {
    const _tasks_0 = _state_0["tasks"];
    return $Core_context_tasks(_tasks_0, _sendNotes_0);
  }
}

function $Core_context(_state_0, _sendNotes_0) {
  return $Core_context_state($$Core_complete(_state_0), _state_0, _sendNotes_0);
}

function $Core_valid_text(_text_0, _bound_0) {
  return $Bool_and($$Bool_not($$String_is_empty($$String_trim(_text_0))), $$Nat_is_le([...str_out(_text_0)].length, _bound_0));
}

function $Core_valid_tags(_tags_0) {
  if (_tags_0.$ === "Nil") {
    return true;
  } else {
    const _h_0 = _tags_0["head"];
    const _t_0 = _tags_0["tail"];
    return $Bool_and($$Core_valid_text(_h_0, 64), $$Core_valid_tags(_t_0));
  }
}

function $Core_valid_optional_title(_value_0) {
  if (_value_0.$ === "None") {
    return true;
  } else {
    const _text_0 = _value_0["value"];
    return $Core_valid_text(_text_0, 200);
  }
}

function $Core_valid_optional_tags(_value_0) {
  if (_value_0.$ === "None") {
    return true;
  } else {
    const _tags_0 = _value_0["value"];
    return $Bool_and($$Nat_is_le($$List_length(_tags_0), 50), $$Core_valid_tags(_tags_0));
  }
}

function $Core_valid_patch(_patch_0) {
  const _title_0 = _patch_0["title"];
  const _tags_0 = _patch_0["tags"];
  return $Bool_and($$Core_valid_optional_title(_title_0), $$Core_valid_optional_tags(_tags_0));
}

function $Core_live(_found_0) {
  if (_found_0.$ === "None") {
    return false;
  } else {
    const _task_0 = _found_0["value"];
    return $Bool_not($$Core_task_deleted(_task_0));
  }
}

function $Core_absent(_found_0) {
  if (_found_0.$ === "None") {
    return true;
  } else {
    return false;
  }
}

function $Core_valid_kind(_kind_0) {
  const _x_0 = (_kind_0 === "morning");
  const _x_1 = (_kind_0 === "evening");
  return (_x_0 || _x_1);
}

function $Core_command_valid(_state_0, _payload_0) {
  if (_payload_0.$ === "Created") {
    const _taskId_0 = _payload_0["taskId"];
    const _title_0 = _payload_0["title"];
    const _tags_0 = _payload_0["tags"];
    return $Bool_and($$Core_absent($$Core_state_task(_state_0, _taskId_0)), $$Bool_and($$Core_valid_text(_title_0, 200), $$Bool_and($$Nat_is_le($$List_length(_tags_0), 50), $$Core_valid_tags(_tags_0))));
  } else if (_payload_0.$ === "StatusChanged") {
    const _taskId_1 = _payload_0["taskId"];
    return $Core_live($$Core_state_task(_state_0, _taskId_1));
  } else if (_payload_0.$ === "Noted") {
    const _taskId_2 = _payload_0["taskId"];
    const _text_0 = _payload_0["text"];
    return $Bool_and($$Core_live($$Core_state_task(_state_0, _taskId_2)), $$Core_valid_text(_text_0, (20000 )));
  } else if (_payload_0.$ === "Edited") {
    const _taskId_3 = _payload_0["taskId"];
    const _patch_0 = _payload_0["patch"];
    return $Bool_and($$Core_live($$Core_state_task(_state_0, _taskId_3)), $$Core_valid_patch(_patch_0));
  } else if (_payload_0.$ === "Deleted") {
    const _taskId_4 = _payload_0["taskId"];
    return $Core_live($$Core_state_task(_state_0, _taskId_4));
  } else if (_payload_0.$ === "SummarySet") {
    const _date_0 = _payload_0["date"];
    const _kind_0 = _payload_0["kind"];
    const _body_0 = _payload_0["body"];
    return $Bool_and($$Bool_not($$String_is_empty(_date_0)), $$Bool_and($$Core_valid_kind(_kind_0), $$Bool_not($$String_is_empty(_body_0))));
  } else if (_payload_0.$ === "StandupSet") {
    const _date_1 = _payload_0["date"];
    const _kind_1 = _payload_0["kind"];
    const _text_1 = _payload_0["text"];
    return $Bool_and($$Bool_not($$String_is_empty(_date_1)), $$Bool_and($$Core_valid_kind(_kind_1), $$Core_valid_text(_text_1, (20000 ))));
  } else {
    return false;
  }
}

function $Core_stage_valid(_event_0, _valid_0) {
  if (!_valid_0) {
    return {$: "StageRejected", "reason": "invalid command or unavailable task"};
  } else {
    return {$: "StageAccepted", "event": _event_0};
  }
}

function $Core_stage_state(_result_0, _event_0) {
  if (_result_0.$ === "ReplayConflict") {
    return {$: "StageRejected", "reason": "event ID content conflict"};
  } else {
    const _state_0 = _result_0["state"];
    const _id_1 = _event_0["id"];
    const _ts_0 = _event_0["ts"];
    const _day_0 = _event_0["day"];
    const _payload_0 = _event_0["payload"];
    const _canonical_0 = _event_0["canonical"];
    return $Core_stage_valid({$: "Ev", "id": _id_1, "ts": _ts_0, "day": _day_0, "payload": _payload_0, "canonical": _canonical_0}, $$Bool_and($$Core_complete(_state_0), $$Bool_and($$Core_command_valid(_state_0, _payload_0), $$Bool_and($$Bool_not($$String_is_empty(_id_1)), $$Bool_and($$Bool_not($$String_is_empty(_ts_0)), $$Bool_not($$String_is_empty(_day_0)))))));
  }
}

function $Core_stage_unique(_event_0, _existing_0, _duplicate_0) {
  if (_duplicate_0) {
    return {$: "StageRejected", "reason": "event ID already exists"};
  } else {
    return $Core_stage_state($$Core_replay(_existing_0), _event_0);
  }
}

function $Core_stage_candidate_complete(_event_0, _valid_0) {
  if (_valid_0) {
    return {$: "StageAccepted", "event": _event_0};
  } else {
    return {$: "StageRejected", "reason": "command would create incomplete history; check its clock and references"};
  }
}

function $Core_stage_candidate_replayed(_result_0, _event_0) {
  if (_result_0.$ === "ReplayConflict") {
    return {$: "StageRejected", "reason": "candidate event content conflict"};
  } else {
    const _state_0 = _result_0["state"];
    return $Core_stage_candidate_complete(_event_0, $$Core_complete(_state_0));
  }
}

function $Core_stage_proposed(_result_0, _existing_0) {
  if (_result_0.$ === "StageRejected") {
    const _reason_0 = _result_0["reason"];
    return {$: "StageRejected", "reason": _reason_0};
  } else {
    const _event_0 = _result_0["event"];
    return $Core_stage_candidate_replayed($$Core_replay($$List_append(_existing_0, {$: "Con", "head": _event_0, "tail": {$: "Nil"}})), _event_0);
  }
}

function $Core_stage(_events_0, _event_0) {
  return $Core_stage_proposed($$Core_stage_unique(_event_0, _events_0, $$Core_ids_contains(_events_0, $$Core_event_id(_event_0))), _events_0);
}

function $Core_schema_allowed(_version_0) {
  const _x_0 = (_version_0 === 1);
  const _x_1 = (_version_0 === 2);
  return (_x_0 || _x_1);
}

function $Core_exact_contains(_events_0, _event_0) {
  if (_events_0.$ === "Nil") {
    return false;
  } else {
    const _h_0 = _events_0["head"];
    const _t_0 = _events_0["tail"];
    const _x_0 = $$Core_event_eq(_h_0, _event_0);
    const _x_1 = $$Core_exact_contains(_t_0, _event_0);
    return (_x_0 || _x_1);
  }
}

function $Core_acknowledge_put(_event_0, _rest_0, _acknowledged_0) {
  if (_acknowledged_0) {
    return _rest_0;
  } else {
    return {$: "Con", "head": _event_0, "tail": _rest_0};
  }
}

function $Core_acknowledge_success(_pending_0, _committed_0) {
  if (_pending_0.$ === "Nil") {
    return {$: "Nil"};
  } else {
    const _h_0 = _pending_0["head"];
    const _t_0 = _pending_0["tail"];
    return $Core_acknowledge_put(_h_0, $$Core_acknowledge_success(_t_0, _committed_0), $$Core_exact_contains(_committed_0, _h_0));
  }
}

function $Core_acknowledge(_pending_0, _committed_0, _success_0) {
  if (!_success_0) {
    return _pending_0;
  } else {
    return $Core_acknowledge_success(_pending_0, _committed_0);
  }
}

function $Core_eligible_found(_found_0) {
  if (_found_0.$ === "None") {
    return false;
  } else {
    const _task_0 = _found_0["value"];
    return $Core_eligible(_task_0);
  }
}

function $Core_eligible_target(_state_0, _id_0) {
  return $Bool_and($$Core_complete(_state_0), $$Core_eligible_found($$Core_state_task(_state_0, _id_0)));
}

function $Core_history_chosen(_event_0, _allowed_0) {
  if (!_allowed_0) {
    return {$: "None"};
  } else {
    return {$: "Some", "value": _event_0};
  }
}

function $Core_history_patch(_patch_0, _id_0, _ts_0, _day_0, _taskId_0) {
  const _title_0 = _patch_0["title"];
  const _status_0 = _patch_0["status"];
  return {$: "ContextEvent", "id": _id_0, "ts": _ts_0, "day": _day_0, "taskId": _taskId_0, "kind": "task.edit", "title": $$Maybe_default(_title_0, ""), "status": _status_0, "text": ""};
}

function $Core_history_payload(_payload_0, _state_0, _id_0, _ts_0, _day_0, _sendNotes_0) {
  if (_payload_0.$ === "Created") {
    const _taskId_0 = _payload_0["taskId"];
    const _title_0 = _payload_0["title"];
    const _status_0 = _payload_0["status"];
    return $Core_history_chosen({$: "ContextEvent", "id": _id_0, "ts": _ts_0, "day": _day_0, "taskId": _taskId_0, "kind": "task.create", "title": _title_0, "status": {$: "Some", "value": _status_0}, "text": ""}, $$Core_eligible_target(_state_0, _taskId_0));
  } else if (_payload_0.$ === "StatusChanged") {
    const _taskId_1 = _payload_0["taskId"];
    const _status_1 = _payload_0["status"];
    return $Core_history_chosen({$: "ContextEvent", "id": _id_0, "ts": _ts_0, "day": _day_0, "taskId": _taskId_1, "kind": "task.status", "title": "", "status": {$: "Some", "value": _status_1}, "text": ""}, $$Core_eligible_target(_state_0, _taskId_1));
  } else if (_payload_0.$ === "Noted") {
    const _taskId_2 = _payload_0["taskId"];
    const _text_0 = _payload_0["text"];
    return $Core_history_chosen({$: "ContextEvent", "id": _id_0, "ts": _ts_0, "day": _day_0, "taskId": _taskId_2, "kind": "task.note", "title": "", "status": {$: "None"}, "text": _text_0}, $$Bool_and(_sendNotes_0, $$Core_eligible_target(_state_0, _taskId_2)));
  } else if (_payload_0.$ === "Edited") {
    const _taskId_3 = _payload_0["taskId"];
    const _patch_0 = _payload_0["patch"];
    return $Core_history_chosen($$Core_history_patch(_patch_0, _id_0, _ts_0, _day_0, _taskId_3), $$Core_eligible_target(_state_0, _taskId_3));
  } else {
    return {$: "None"};
  }
}

function $Core_in_window(_day_0, _startDay_0, _endDay_0) {
  return $Bool_and($$String_is_ge(_day_0, _startDay_0), $$String_is_le(_day_0, _endDay_0));
}

function $Core_history_window(_event_0, _allowed_0) {
  if (!_allowed_0) {
    return {$: "None"};
  } else {
    return _event_0;
  }
}

function $Core_history_event(_event_0, _state_0, _sendNotes_0, _startDay_0, _endDay_0) {
  const _id_0 = _event_0["id"];
  const _ts_0 = _event_0["ts"];
  const _day_0 = _event_0["day"];
  const _payload_0 = _event_0["payload"];
  return $Core_history_window($$Core_history_payload(_payload_0, _state_0, _id_0, _ts_0, _day_0, _sendNotes_0), $$Core_in_window(_day_0, _startDay_0, _endDay_0));
}

function $Core_history_put(_chosen_0, _rest_0) {
  if (_chosen_0.$ === "None") {
    return _rest_0;
  } else {
    const _event_0 = _chosen_0["value"];
    return {$: "Con", "head": _event_0, "tail": _rest_0};
  }
}

function $Core_context_events_go(_events_0, _state_0, _sendNotes_0, _startDay_0, _endDay_0) {
  if (_events_0.$ === "Nil") {
    return {$: "Nil"};
  } else {
    const _h_0 = _events_0["head"];
    const _t_0 = _events_0["tail"];
    return $Core_history_put($$Core_history_event(_h_0, _state_0, _sendNotes_0, _startDay_0, _endDay_0), $$Core_context_events_go(_t_0, _state_0, _sendNotes_0, _startDay_0, _endDay_0));
  }
}

function $Core_context_events(_state_0, _events_0, _sendNotes_0, _startDay_0, _endDay_0) {
  return $Core_context_events_go(_events_0, _state_0, _sendNotes_0, _startDay_0, _endDay_0);
}

function $Core_proposal_target_valid(_state_0, _payload_0) {
  if (_payload_0.$ === "Created") {
    return true;
  } else if (_payload_0.$ === "StatusChanged") {
    const _taskId_1 = _payload_0["taskId"];
    return $Core_eligible_target(_state_0, _taskId_1);
  } else if (_payload_0.$ === "Noted") {
    const _taskId_2 = _payload_0["taskId"];
    return $Core_eligible_target(_state_0, _taskId_2);
  } else if (_payload_0.$ === "Edited") {
    const _taskId_3 = _payload_0["taskId"];
    return $Core_eligible_target(_state_0, _taskId_3);
  } else {
    return false;
  }
}

function $Core_proposal_state(_result_0, _events_0, _event_0) {
  if (_result_0.$ === "ReplayConflict") {
    return {$: "StageRejected", "reason": "event ID content conflict"};
  } else {
    const _state_0 = _result_0["state"];
    const _id_1 = _event_0["id"];
    const _ts_0 = _event_0["ts"];
    const _day_0 = _event_0["day"];
    const _payload_0 = _event_0["payload"];
    const _canonical_0 = _event_0["canonical"];
    return $Bool_pick($$Core_proposal_target_valid(_state_0, _payload_0), $$Core_stage(_events_0, {$: "Ev", "id": _id_1, "ts": _ts_0, "day": _day_0, "payload": _payload_0, "canonical": _canonical_0}), {$: "StageRejected", "reason": "proposal target is not eligible"});
  }
}

function $Core_proposal_stage(_events_0, _event_0) {
  return $Core_proposal_state($$Core_replay(_events_0), _events_0, _event_0);
}

function $schemas_compatible(_schemas_0) {
  if (_schemas_0.$ === "Nil") {
    return true;
  } else {
    const _schema_0 = _schemas_0["head"];
    const _rest_0 = _schemas_0["tail"];
    return $Bool_and($$Core_schema_allowed(_schema_0), $$schemas_compatible(_rest_0));
  }
}

function $approved(_schemas_0, _approved_plan_0, _execution_plan_0) {
  return $Bool_and($$schemas_compatible(_schemas_0), (_approved_plan_0 === _execution_plan_0));
}

function $Cmp_is_eq(_c_0) {
  if (_c_0.$ === "EQ") {
    return true;
  } else {
    return false;
  }
}

function $Bool_cmp(_a_0, _b_0) {
  if (!_a_0) {
    if (!_b_0) {
      return {$: "EQ"};
    } else {
      return {$: "LT"};
    }
  } else {
    if (!_b_0) {
      return {$: "GT"};
    } else {
      return {$: "EQ"};
    }
  }
}

function $Bool_and(_a_0, _b_0) {
  if (!_a_0) {
    return false;
  } else {
    return _b_0;
  }
}

function $String_is_le(_a_0, _b_0) {
  return $Cmp_is_le($$String_order(_a_0, _b_0));
}

function $List_sort_0(_xs_0) {
  if (_xs_0.$ === "Nil") {
    return {$: "Nil"};
  } else {
    const _h_0 = _xs_0["head"];
    const _t_0 = _xs_0["tail"];
    const _ys_0 = {$: "Con", "head": _h_0, "tail": _t_0};
    const _n_0 = $$List_length(_ys_0);
    return $List_sort_go_0(_n_0, _n_0, $$List_sort_pairs_0(_ys_0));
  }
}

function $Bool_pick(_c_0, _a_0, _b_0) {
  if (!_c_0) {
    return _b_0;
  } else {
    return _a_0;
  }
}

function $Bool_not(_b_0) {
  if (!_b_0) {
    return true;
  } else {
    return false;
  }
}

function $List_sort_1(_xs_0) {
  if (_xs_0.$ === "Nil") {
    return {$: "Nil"};
  } else {
    const _h_0 = _xs_0["head"];
    const _t_0 = _xs_0["tail"];
    const _ys_0 = {$: "Con", "head": _h_0, "tail": _t_0};
    const _n_0 = $$List_length(_ys_0);
    return $List_sort_go_1(_n_0, _n_0, $$List_sort_pairs_1(_ys_0));
  }
}

function $List_append(_xs_0, _ys_0) {
  if (_xs_0.$ === "Nil") {
    return _ys_0;
  } else {
    const _h_0 = _xs_0["head"];
    const _t_0 = _xs_0["tail"];
    return {$: "Con", "head": _h_0, "tail": $$List_append(_t_0, _ys_0)};
  }
}

function $Maybe_default(_m_0, _d_0) {
  if (_m_0.$ === "None") {
    return _d_0;
  } else {
    const _x_0 = _m_0["value"];
    return _x_0;
  }
}

function $String_is_empty(_s_0) {
  if (_s_0 === "") {
    return true;
  } else {
    return false;
  }
}

function $String_trim(_s_0) {
  return $String_trim_end($$String_trim_start(_s_0));
}

function $Nat_is_le(_a_0, _b_0) {
  return $Cmp_is_le(cmp_new(_a_0, _b_0));
}

function $List_length(_xs_0) {
  if (_xs_0.$ === "Nil") {
    return 0;
  } else {
    const _t_0 = _xs_0["tail"];
    return nat_chk($$List_length(_t_0) + 1);
  }
}

function $String_is_ge(_a_0, _b_0) {
  return $Cmp_is_ge($$String_order(_a_0, _b_0));
}

function $String_order(_a_0, _b_0) {
  return $String_order_go(_a_0, _b_0, {$: "EQ"});
}

function $Cmp_is_le(_c_0) {
  if (_c_0.$ === "GT") {
    return false;
  } else {
    return true;
  }
}

function $List_sort_go_0($0, $1, $2) {
  for (;;) {
    {
      const _fuel_0 = $0;
      const _n_0 = $1;
      const _runs_0 = $2;
      if (_fuel_0 == 0) {
        return $List_concat(_runs_0);
      } else {
        const _f_0 = (_fuel_0 - 1);
        if (_runs_0.$ === "Nil") {
          return {$: "Nil"};
        } else {
          const _r_0 = _runs_0["head"];
          const _t_0 = _runs_0["tail"];
          if (_t_0.$ === "Nil") {
            return _r_0;
          } else {
            const _r2_0 = _t_0["head"];
            const _rest_0 = _t_0["tail"];
            $0 = _f_0;
            $1 = _n_0;
            $2 = $$List_sort_pass_0(_n_0, {$: "Con", "head": _r_0, "tail": {$: "Con", "head": _r2_0, "tail": _rest_0}});
            continue;
          }
        }
      }
    }
  }
}

function $List_sort_pairs_0(_xs_0) {
  if (_xs_0.$ === "Nil") {
    return {$: "Nil"};
  } else {
    const _x_0 = _xs_0["head"];
    const _t_0 = _xs_0["tail"];
    if (_t_0.$ === "Nil") {
      return {$: "Con", "head": {$: "Con", "head": _x_0, "tail": {$: "Nil"}}, "tail": {$: "Nil"}};
    } else {
      const _y_0 = _t_0["head"];
      const _t_1 = _t_0["tail"];
      return {$: "Con", "head": $$List_sort_pair(_x_0, _y_0, $$Core_event_le(_x_0, _y_0)), "tail": $$List_sort_pairs_0(_t_1)};
    }
  }
}

function $List_sort_go_1($0, $1, $2) {
  for (;;) {
    {
      const _fuel_0 = $0;
      const _n_0 = $1;
      const _runs_0 = $2;
      if (_fuel_0 == 0) {
        return $List_concat(_runs_0);
      } else {
        const _f_0 = (_fuel_0 - 1);
        if (_runs_0.$ === "Nil") {
          return {$: "Nil"};
        } else {
          const _r_0 = _runs_0["head"];
          const _t_0 = _runs_0["tail"];
          if (_t_0.$ === "Nil") {
            return _r_0;
          } else {
            const _r2_0 = _t_0["head"];
            const _rest_0 = _t_0["tail"];
            $0 = _f_0;
            $1 = _n_0;
            $2 = $$List_sort_pass_1(_n_0, {$: "Con", "head": _r_0, "tail": {$: "Con", "head": _r2_0, "tail": _rest_0}});
            continue;
          }
        }
      }
    }
  }
}

function $List_sort_pairs_1(_xs_0) {
  if (_xs_0.$ === "Nil") {
    return {$: "Nil"};
  } else {
    const _x_0 = _xs_0["head"];
    const _t_0 = _xs_0["tail"];
    if (_t_0.$ === "Nil") {
      return {$: "Con", "head": {$: "Con", "head": _x_0, "tail": {$: "Nil"}}, "tail": {$: "Nil"}};
    } else {
      const _y_0 = _t_0["head"];
      const _t_1 = _t_0["tail"];
      return {$: "Con", "head": $$List_sort_pair(_x_0, _y_0, $$Core_event_id_le(_x_0, _y_0)), "tail": $$List_sort_pairs_1(_t_1)};
    }
  }
}

function $String_trim_end(_s_0) {
  return $String_reverse($$String_trim_start($$String_reverse(_s_0)));
}

function $String_trim_start($0, $1, $2) {
  let $pc = 0;
  for (;;) switch ($pc) {
    case 0: {
      const _s_0 = $0;
      if (_s_0 === "") {
        return "";
      } else {
        const _h_0 = _s_0.slice(0, char_len(_s_0));
        const _t_0 = _s_0.slice(char_len(_s_0));
        $0 = _t_0;
        $1 = _h_0;
        $2 = $$Char_is_space(_h_0);
        $pc = 1; continue;
      }
    }
    case 1: {
      const _t_0 = $0;
      const _h_0 = $1;
      const _space_0 = $2;
      if (!_space_0) {
        return (_h_0 + _t_0);
      } else {
        $0 = _t_0;
        $pc = 0; continue;
      }
    }
  }
}

function $Cmp_is_ge(_c_0) {
  if (_c_0.$ === "LT") {
    return false;
  } else {
    return true;
  }
}

function $String_order_go($0, $1, $2) {
  for (;;) {
    {
      const _a_0 = $0;
      const _b_0 = $1;
      const _c_0 = $2;
      if (_a_0 === "") {
        if (_b_0 !== "") {
          if (_c_0.$ === "EQ") {
            return {$: "LT"};
          } else {
            return _c_0;
          }
        } else {
          return _c_0;
        }
      } else {
        const _t_1 = _a_0.slice(0, char_len(_a_0));
        const _x_0 = char_code(_t_1);
        const _t_2 = _a_0.slice(char_len(_a_0));
        if (_b_0 === "") {
          if (_c_0.$ === "EQ") {
            return {$: "GT"};
          } else {
            return _c_0;
          }
        } else {
          const _t_3 = _b_0.slice(0, char_len(_b_0));
          const _y_0 = char_code(_t_3);
          const _t2_0 = _b_0.slice(char_len(_b_0));
          if (_c_0.$ === "EQ") {
            $0 = _t_2;
            $1 = _t2_0;
            $2 = cmp_new(_x_0, _y_0);
            continue;
          } else {
            return _c_0;
          }
        }
      }
    }
  }
}

function $List_concat(_xss_0) {
  if (_xss_0.$ === "Nil") {
    return {$: "Nil"};
  } else {
    const _h_0 = _xss_0["head"];
    const _t_0 = _xss_0["tail"];
    return $List_append(_h_0, $$List_concat(_t_0));
  }
}

function $List_sort_pass_0(_n_0, _runs_0) {
  if (_runs_0.$ === "Nil") {
    return {$: "Nil"};
  } else {
    const _r_0 = _runs_0["head"];
    const _t_0 = _runs_0["tail"];
    if (_t_0.$ === "Nil") {
      return {$: "Con", "head": _r_0, "tail": {$: "Nil"}};
    } else {
      const _r2_0 = _t_0["head"];
      const _rest_0 = _t_0["tail"];
      return {$: "Con", "head": $$List_merge_go_0(_n_0, {$: "Tuple", "fst": {$: "Nil"}, "snd": {$: "Tuple", "fst": _r_0, "snd": _r2_0}}), "tail": $$List_sort_pass_0(_n_0, _rest_0)};
    }
  }
}

function $List_sort_pair(_x_0, _y_0, _le_0) {
  if (_le_0) {
    return {$: "Con", "head": _x_0, "tail": {$: "Con", "head": _y_0, "tail": {$: "Nil"}}};
  } else {
    return {$: "Con", "head": _y_0, "tail": {$: "Con", "head": _x_0, "tail": {$: "Nil"}}};
  }
}

function $List_sort_pass_1(_n_0, _runs_0) {
  if (_runs_0.$ === "Nil") {
    return {$: "Nil"};
  } else {
    const _r_0 = _runs_0["head"];
    const _t_0 = _runs_0["tail"];
    if (_t_0.$ === "Nil") {
      return {$: "Con", "head": _r_0, "tail": {$: "Nil"}};
    } else {
      const _r2_0 = _t_0["head"];
      const _rest_0 = _t_0["tail"];
      return {$: "Con", "head": $$List_merge_go_1(_n_0, {$: "Tuple", "fst": {$: "Nil"}, "snd": {$: "Tuple", "fst": _r_0, "snd": _r2_0}}), "tail": $$List_sort_pass_1(_n_0, _rest_0)};
    }
  }
}

function $String_reverse(_s_0) {
  return $String_reverse_go(_s_0, "");
}

function $String_trim_start_if($0, $1, $2) {
  let $pc = 1;
  for (;;) switch ($pc) {
    case 0: {
      const _s_0 = $0;
      if (_s_0 === "") {
        return "";
      } else {
        const _h_0 = _s_0.slice(0, char_len(_s_0));
        const _t_0 = _s_0.slice(char_len(_s_0));
        $0 = _t_0;
        $1 = _h_0;
        $2 = $$Char_is_space(_h_0);
        $pc = 1; continue;
      }
    }
    case 1: {
      const _t_0 = $0;
      const _h_0 = $1;
      const _space_0 = $2;
      if (!_space_0) {
        return (_h_0 + _t_0);
      } else {
        $0 = _t_0;
        $pc = 0; continue;
      }
    }
  }
}

function $Char_is_space(_c_0) {
  const _x_0 = char_code(_c_0);
  const _x_1 = (_x_0 === 32);
  const _x_2 = $$Bool_and((_x_0 >= 9), (_x_0 <= 13));
  return (_x_1 || _x_2);
}

function $List_merge_go_0($0, $1) {
  for (;;) {
    {
      const _fuel_0 = $0;
      const _st_0 = $1;
      if (_fuel_0 == 0) {
        const _acc_0 = _st_0["fst"];
        const _t_0 = _st_0["snd"];
        const _xs_0 = _t_0["fst"];
        const _ys_0 = _t_0["snd"];
        return $List_reverse_go(_acc_0, $$List_append(_xs_0, _ys_0));
      } else {
        const _f_0 = (_fuel_0 - 1);
        const _acc_1 = _st_0["fst"];
        const _t_1 = _st_0["snd"];
        const _t_2 = _t_1["fst"];
        if (_t_2.$ === "Nil") {
          const _t_3 = _t_1["snd"];
          if (_t_3.$ === "Nil") {
            return $List_reverse_go(_acc_1, {$: "Nil"});
          } else {
            const _y_0 = _t_3["head"];
            const _yt_0 = _t_3["tail"];
            return $List_reverse_go(_acc_1, {$: "Con", "head": _y_0, "tail": _yt_0});
          }
        } else {
          const _x_0 = _t_2["head"];
          const _xt_0 = _t_2["tail"];
          const _t_4 = _t_1["snd"];
          if (_t_4.$ === "Nil") {
            return $List_reverse_go(_acc_1, {$: "Con", "head": _x_0, "tail": _xt_0});
          } else {
            const _y_1 = _t_4["head"];
            const _yt_1 = _t_4["tail"];
            $0 = _f_0;
            $1 = $$List_merge_step(_acc_1, _x_0, _xt_0, _y_1, _yt_1, $$Core_event_le(_x_0, _y_1));
            continue;
          }
        }
      }
    }
  }
}

function $List_merge_go_1($0, $1) {
  for (;;) {
    {
      const _fuel_0 = $0;
      const _st_0 = $1;
      if (_fuel_0 == 0) {
        const _acc_0 = _st_0["fst"];
        const _t_0 = _st_0["snd"];
        const _xs_0 = _t_0["fst"];
        const _ys_0 = _t_0["snd"];
        return $List_reverse_go(_acc_0, $$List_append(_xs_0, _ys_0));
      } else {
        const _f_0 = (_fuel_0 - 1);
        const _acc_1 = _st_0["fst"];
        const _t_1 = _st_0["snd"];
        const _t_2 = _t_1["fst"];
        if (_t_2.$ === "Nil") {
          const _t_3 = _t_1["snd"];
          if (_t_3.$ === "Nil") {
            return $List_reverse_go(_acc_1, {$: "Nil"});
          } else {
            const _y_0 = _t_3["head"];
            const _yt_0 = _t_3["tail"];
            return $List_reverse_go(_acc_1, {$: "Con", "head": _y_0, "tail": _yt_0});
          }
        } else {
          const _x_0 = _t_2["head"];
          const _xt_0 = _t_2["tail"];
          const _t_4 = _t_1["snd"];
          if (_t_4.$ === "Nil") {
            return $List_reverse_go(_acc_1, {$: "Con", "head": _x_0, "tail": _xt_0});
          } else {
            const _y_1 = _t_4["head"];
            const _yt_1 = _t_4["tail"];
            $0 = _f_0;
            $1 = $$List_merge_step(_acc_1, _x_0, _xt_0, _y_1, _yt_1, $$Core_event_id_le(_x_0, _y_1));
            continue;
          }
        }
      }
    }
  }
}

function $String_reverse_go($0, $1) {
  for (;;) {
    {
      const _s_0 = $0;
      const _acc_0 = $1;
      if (_s_0 === "") {
        return _acc_0;
      } else {
        const _h_0 = _s_0.slice(0, char_len(_s_0));
        const _t_0 = _s_0.slice(char_len(_s_0));
        $0 = _t_0;
        $1 = (_h_0 + _acc_0);
        continue;
      }
    }
  }
}

function $List_reverse_go($0, $1) {
  for (;;) {
    {
      const _xs_0 = $0;
      const _acc_0 = $1;
      if (_xs_0.$ === "Nil") {
        return _acc_0;
      } else {
        const _h_0 = _xs_0["head"];
        const _t_0 = _xs_0["tail"];
        $0 = _t_0;
        $1 = {$: "Con", "head": _h_0, "tail": _acc_0};
        continue;
      }
    }
  }
}

function $List_merge_step(_acc_0, _x_0, _xt_0, _y_0, _yt_0, _le_0) {
  if (!_le_0) {
    return {$: "Tuple", "fst": {$: "Con", "head": _y_0, "tail": _acc_0}, "snd": {$: "Tuple", "fst": {$: "Con", "head": _x_0, "tail": _xt_0}, "snd": _yt_0}};
  } else {
    return {$: "Tuple", "fst": {$: "Con", "head": _x_0, "tail": _acc_0}, "snd": {$: "Tuple", "fst": _xt_0, "snd": {$: "Con", "head": _y_0, "tail": _yt_0}}};
  }
}

const $$Bool_cmp = $Bool_cmp;
const $$Core_strings_eq = $Core_strings_eq;
const $$Core_optional_string_eq = $Core_optional_string_eq;
const $$Core_optional_status_eq = $Core_optional_status_eq;
const $$Core_optional_priority_eq = $Core_optional_priority_eq;
const $$Core_optional_strings_eq = $Core_optional_strings_eq;
const $$Core_optional_bool_eq = $Core_optional_bool_eq;
const $$Bool_and = $Bool_and;
const $$Core_status_eq = $Core_status_eq;
const $$Core_priority_eq = $Core_priority_eq;
const $$Core_bool_eq = $Core_bool_eq;
const $$Core_patch_eq = $Core_patch_eq;
const $$Core_payload_eq = $Core_payload_eq;
const $$Core_event_id = $Core_event_id;
const $$Core_ids_contains = $Core_ids_contains;
const $$List_sort_0 = $List_sort_0;
const $$Core_event_eq = $Core_event_eq;
const $$Bool_not = $Bool_not;
const $$Core_unique_put = $Core_unique_put;
const $$Core_scan_ids = $Core_scan_ids;
const $$List_append = $List_append;
const $$List_sort_1 = $List_sort_1;
const $$Core_chosen_notes = $Core_chosen_notes;
const $$Core_task_id = $Core_task_id;
const $$Core_task_find = $Core_task_find;
const $$Core_put_task = $Core_put_task;
const $$Core_record_key_equal = $Core_record_key_equal;
const $$Core_put_record = $Core_put_record;
const $$Maybe_default = $Maybe_default;
const $$Core_patch_completion = $Core_patch_completion;
const $$Core_apply_payload = $Core_apply_payload;
const $$Core_task_deleted = $Core_task_deleted;
const $$Core_state_task = $Core_state_task;
const $$Core_completion = $Core_completion;
const $$Core_apply_event = $Core_apply_event;
const $$Core_empty_state = $Core_empty_state;
const $$Core_fold_sorted = $Core_fold_sorted;
const $$Core_merge = $Core_merge;
const $$Core_project = $Core_project;
const $$Core_context_tasks = $Core_context_tasks;
const $$Core_eligible = $Core_eligible;
const $$Core_complete = $Core_complete;
const $$String_trim = $String_trim;
const $$String_is_empty = $String_is_empty;
const $$Nat_is_le = $Nat_is_le;
const $$Core_valid_text = $Core_valid_text;
const $$Core_valid_tags = $Core_valid_tags;
const $$List_length = $List_length;
const $$Core_valid_optional_title = $Core_valid_optional_title;
const $$Core_valid_optional_tags = $Core_valid_optional_tags;
const $$Core_absent = $Core_absent;
const $$Core_live = $Core_live;
const $$Core_valid_patch = $Core_valid_patch;
const $$Core_valid_kind = $Core_valid_kind;
const $$Core_command_valid = $Core_command_valid;
const $$Core_replay = $Core_replay;
const $$Core_stage_unique = $Core_stage_unique;
const $$Core_exact_contains = $Core_exact_contains;
const $$Core_acknowledge_success = $Core_acknowledge_success;
const $$Core_eligible_found = $Core_eligible_found;
const $$Core_eligible_target = $Core_eligible_target;
const $$Core_history_patch = $Core_history_patch;
const $$String_is_ge = $String_is_ge;
const $$String_is_le = $String_is_le;
const $$Core_history_payload = $Core_history_payload;
const $$Core_in_window = $Core_in_window;
const $$Core_history_event = $Core_history_event;
const $$Core_context_events_go = $Core_context_events_go;
const $$Core_proposal_target_valid = $Core_proposal_target_valid;
const $$Core_stage = $Core_stage;
const $$Core_schema_allowed = $Core_schema_allowed;
const $$schemas_compatible = $schemas_compatible;
const $$String_order = $String_order;
const $$List_sort_pairs_0 = $List_sort_pairs_0;
const $$List_sort_pairs_1 = $List_sort_pairs_1;
const $$String_trim_start = $String_trim_start;
const $$List_sort_pass_0 = $List_sort_pass_0;
const $$Core_event_le = $Core_event_le;
const $$List_sort_pair = $List_sort_pair;
const $$List_sort_pass_1 = $List_sort_pass_1;
const $$Core_event_id_le = $Core_event_id_le;
const $$String_reverse = $String_reverse;
const $$Char_is_space = $Char_is_space;
const $$List_concat = $List_concat;
const $$List_merge_go_0 = $List_merge_go_0;
const $$List_merge_go_1 = $List_merge_go_1;
const $$List_merge_step = $List_merge_step;export default {
  "Core:status_eq": run_lib((a0,a1) => run_loop($Core_status_eq(a0,a1)), 2),
  "Core:priority_eq": run_lib((a0,a1) => run_loop($Core_priority_eq(a0,a1)), 2),
  "Core:bool_eq": run_lib((a0,a1) => run_loop($Core_bool_eq(a0,a1)), 2),
  "Core:strings_eq": run_lib((a0,a1) => run_loop($Core_strings_eq(a0,a1)), 2),
  "Core:optional_string_eq": run_lib((a0,a1) => run_loop($Core_optional_string_eq(a0,a1)), 2),
  "Core:optional_status_eq": run_lib((a0,a1) => run_loop($Core_optional_status_eq(a0,a1)), 2),
  "Core:optional_priority_eq": run_lib((a0,a1) => run_loop($Core_optional_priority_eq(a0,a1)), 2),
  "Core:optional_strings_eq": run_lib((a0,a1) => run_loop($Core_optional_strings_eq(a0,a1)), 2),
  "Core:optional_bool_eq": run_lib((a0,a1) => run_loop($Core_optional_bool_eq(a0,a1)), 2),
  "Core:patch_eq": run_lib((a0,a1) => run_loop($Core_patch_eq(a0,a1)), 2),
  "Core:payload_eq": run_lib((a0,a1) => run_loop($Core_payload_eq(a0,a1)), 2),
  "Core:event_id": run_lib((a0) => str_out(run_loop($Core_event_id(a0))), 1),
  "Core:event_eq": run_lib((a0,a1) => run_loop($Core_event_eq(a0,a1)), 2),
  "Core:event_le_tie": run_lib((a0,a1,a2,a3,a4) => run_loop($Core_event_le_tie(str_in(a0),str_in(a1),str_in(a2),str_in(a3),a4)), 5),
  "Core:event_le": run_lib((a0,a1) => run_loop($Core_event_le(a0,a1)), 2),
  "Core:ids_contains": run_lib((a0,a1) => run_loop($Core_ids_contains(a0,str_in(a1))), 2),
  "Core:unique_put": run_lib((a0,a1,a2) => run_loop($Core_unique_put(a0,a1,a2)), 3),
  "Core:event_id_le": run_lib((a0,a1) => run_loop($Core_event_id_le(a0,a1)), 2),
  "Core:scan_ids": run_lib((a0,a1,a2) => run_loop($Core_scan_ids(a0,a1,a2)), 3),
  "Core:merge": run_lib((a0,a1) => run_loop($Core_merge(a0,a1)), 2),
  "Core:completion": run_lib((a0,a1) => run_loop($Core_completion(a0,str_in(a1))), 2),
  "Core:eligible": run_lib((a0) => run_loop($Core_eligible(a0)), 1),
  "Core:chosen_notes": run_lib((a0,a1) => run_loop($Core_chosen_notes(a0,a1)), 2),
  "Core:project": run_lib((a0,a1) => run_loop($Core_project(a0,a1)), 2),
  "Core:context_notes": run_lib((a0) => run_loop($Core_context_notes(a0)), 1),
  "Core:task_id": run_lib((a0) => str_out(run_loop($Core_task_id(a0))), 1),
  "Core:task_deleted": run_lib((a0) => run_loop($Core_task_deleted(a0)), 1),
  "Core:task_find": run_lib((a0,a1) => run_loop($Core_task_find(a0,str_in(a1))), 2),
  "Core:put_task": run_lib((a0,a1) => run_loop($Core_put_task(a0,a1)), 2),
  "Core:record_key_equal": run_lib((a0,a1) => run_loop($Core_record_key_equal(a0,a1)), 2),
  "Core:put_record": run_lib((a0,a1) => run_loop($Core_put_record(a0,a1)), 2),
  "Core:patch_completion": run_lib((a0,a1,a2) => run_loop($Core_patch_completion(a0,str_in(a1),a2)), 3),
  "Core:edit_task": run_lib((a0,a1,a2) => run_loop($Core_edit_task(a0,a1,str_in(a2))), 3),
  "Core:note_task": run_lib((a0,a1,a2) => run_loop($Core_note_task(a0,a1,str_in(a2))), 3),
  "Core:delete_task": run_lib((a0,a1) => run_loop($Core_delete_task(a0,str_in(a1))), 2),
  "Core:apply_payload": run_lib((a0,a1,a2,a3) => run_loop($Core_apply_payload(a0,a1,str_in(a2),str_in(a3))), 4),
  "Core:empty_state": run_lib(() => run_loop($Core_empty_state()), 0),
  "Core:diagnostic": run_lib((a0,a1) => run_loop($Core_diagnostic(a0,a1)), 2),
  "Core:state_put": run_lib((a0,a1) => run_loop($Core_state_put(a0,a1)), 2),
  "Core:state_task": run_lib((a0,a1) => run_loop($Core_state_task(a0,str_in(a1))), 2),
  "Core:create_found": run_lib((a0,a1,a2,a3,a4) => run_loop($Core_create_found(a0,a1,str_in(a2),str_in(a3),a4)), 5),
  "Core:update_live": run_lib((a0,a1,a2,a3,a4,a5,a6) => run_loop($Core_update_live(a0,a1,a2,str_in(a3),str_in(a4),str_in(a5),a6)), 7),
  "Core:update_found": run_lib((a0,a1,a2,a3,a4,a5) => run_loop($Core_update_found(a0,a1,str_in(a2),str_in(a3),str_in(a4),a5)), 6),
  "Core:update_existing": run_lib((a0,a1,a2,a3,a4) => run_loop($Core_update_existing(a0,a1,str_in(a2),str_in(a3),str_in(a4))), 5),
  "Core:apply_summary": run_lib((a0,a1) => run_loop($Core_apply_summary(a0,a1)), 2),
  "Core:apply_report": run_lib((a0,a1) => run_loop($Core_apply_report(a0,a1)), 2),
  "Core:apply_event": run_lib((a0,a1) => run_loop($Core_apply_event(a0,a1)), 2),
  "Core:fold_sorted": run_lib((a0,a1) => run_loop($Core_fold_sorted(a0,a1)), 2),
  "Core:replay_merged": run_lib((a0) => run_loop($Core_replay_merged(a0)), 1),
  "Core:replay": run_lib((a0) => run_loop($Core_replay(a0)), 1),
  "Core:reconcile": run_lib((a0,a1) => run_loop($Core_reconcile(a0,a1)), 2),
  "Core:complete": run_lib((a0) => run_loop($Core_complete(a0)), 1),
  "Core:context_put": run_lib((a0,a1,a2,a3) => run_loop($Core_context_put(a0,a1,a2,a3)), 4),
  "Core:context_tasks": run_lib((a0,a1) => run_loop($Core_context_tasks(a0,a1)), 2),
  "Core:context_state": run_lib((a0,a1,a2) => run_loop($Core_context_state(a0,a1,a2)), 3),
  "Core:context": run_lib((a0,a1) => run_loop($Core_context(a0,a1)), 2),
  "Core:valid_text": run_lib((a0,a1) => run_loop($Core_valid_text(str_in(a0),nat_in(a1))), 2),
  "Core:valid_tags": run_lib((a0) => run_loop($Core_valid_tags(a0)), 1),
  "Core:valid_optional_title": run_lib((a0) => run_loop($Core_valid_optional_title(a0)), 1),
  "Core:valid_optional_tags": run_lib((a0) => run_loop($Core_valid_optional_tags(a0)), 1),
  "Core:valid_patch": run_lib((a0) => run_loop($Core_valid_patch(a0)), 1),
  "Core:live": run_lib((a0) => run_loop($Core_live(a0)), 1),
  "Core:absent": run_lib((a0) => run_loop($Core_absent(a0)), 1),
  "Core:valid_kind": run_lib((a0) => run_loop($Core_valid_kind(str_in(a0))), 1),
  "Core:command_valid": run_lib((a0,a1) => run_loop($Core_command_valid(a0,a1)), 2),
  "Core:stage_valid": run_lib((a0,a1) => run_loop($Core_stage_valid(a0,a1)), 2),
  "Core:stage_state": run_lib((a0,a1) => run_loop($Core_stage_state(a0,a1)), 2),
  "Core:stage_unique": run_lib((a0,a1,a2) => run_loop($Core_stage_unique(a0,a1,a2)), 3),
  "Core:stage_candidate_complete": run_lib((a0,a1) => run_loop($Core_stage_candidate_complete(a0,a1)), 2),
  "Core:stage_candidate_replayed": run_lib((a0,a1) => run_loop($Core_stage_candidate_replayed(a0,a1)), 2),
  "Core:stage_proposed": run_lib((a0,a1) => run_loop($Core_stage_proposed(a0,a1)), 2),
  "Core:stage": run_lib((a0,a1) => run_loop($Core_stage(a0,a1)), 2),
  "Core:schema_allowed": run_lib((a0) => run_loop($Core_schema_allowed(a0)), 1),
  "Core:exact_contains": run_lib((a0,a1) => run_loop($Core_exact_contains(a0,a1)), 2),
  "Core:acknowledge_put": run_lib((a0,a1,a2) => run_loop($Core_acknowledge_put(a0,a1,a2)), 3),
  "Core:acknowledge_success": run_lib((a0,a1) => run_loop($Core_acknowledge_success(a0,a1)), 2),
  "Core:acknowledge": run_lib((a0,a1,a2) => run_loop($Core_acknowledge(a0,a1,a2)), 3),
  "Core:eligible_found": run_lib((a0) => run_loop($Core_eligible_found(a0)), 1),
  "Core:eligible_target": run_lib((a0,a1) => run_loop($Core_eligible_target(a0,str_in(a1))), 2),
  "Core:history_chosen": run_lib((a0,a1) => run_loop($Core_history_chosen(a0,a1)), 2),
  "Core:history_patch": run_lib((a0,a1,a2,a3,a4) => run_loop($Core_history_patch(a0,str_in(a1),str_in(a2),str_in(a3),str_in(a4))), 5),
  "Core:history_payload": run_lib((a0,a1,a2,a3,a4,a5) => run_loop($Core_history_payload(a0,a1,str_in(a2),str_in(a3),str_in(a4),a5)), 6),
  "Core:in_window": run_lib((a0,a1,a2) => run_loop($Core_in_window(str_in(a0),str_in(a1),str_in(a2))), 3),
  "Core:history_window": run_lib((a0,a1) => run_loop($Core_history_window(a0,a1)), 2),
  "Core:history_event": run_lib((a0,a1,a2,a3,a4) => run_loop($Core_history_event(a0,a1,a2,str_in(a3),str_in(a4))), 5),
  "Core:history_put": run_lib((a0,a1) => run_loop($Core_history_put(a0,a1)), 2),
  "Core:context_events_go": run_lib((a0,a1,a2,a3,a4) => run_loop($Core_context_events_go(a0,a1,a2,str_in(a3),str_in(a4))), 5),
  "Core:context_events": run_lib((a0,a1,a2,a3,a4) => run_loop($Core_context_events(a0,a1,a2,str_in(a3),str_in(a4))), 5),
  "Core:proposal_target_valid": run_lib((a0,a1) => run_loop($Core_proposal_target_valid(a0,a1)), 2),
  "Core:proposal_state": run_lib((a0,a1,a2) => run_loop($Core_proposal_state(a0,a1,a2)), 3),
  "Core:proposal_stage": run_lib((a0,a1) => run_loop($Core_proposal_stage(a0,a1)), 2),
  "schemas_compatible": run_lib((a0) => run_loop($schemas_compatible(a0)), 1),
  "approved": run_lib((a0,a1,a2) => run_loop($approved(a0,str_in(a1),str_in(a2))), 3),
};
