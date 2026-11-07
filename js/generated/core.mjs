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

function $status_eq(_a_0, _b_0) {
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

function $priority_eq(_a_0, _b_0) {
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

function $bool_eq(_a_0, _b_0) {
  return $Cmp_is_eq($$Bool_cmp(_a_0, _b_0));
}

function $strings_eq(_xs_0, _ys_0) {
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
      return $Bool_and((_x_0 === _y_0), $$strings_eq(_xt_0, _yt_0));
    } else {
      return false;
    }
  }
}

function $optional_string_eq(_a_0, _b_0) {
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

function $optional_status_eq(_a_0, _b_0) {
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
      return $status_eq(_x_0, _y_0);
    } else {
      return false;
    }
  }
}

function $optional_priority_eq(_a_0, _b_0) {
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
      return $priority_eq(_x_0, _y_0);
    } else {
      return false;
    }
  }
}

function $optional_strings_eq(_a_0, _b_0) {
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
      return $strings_eq(_x_0, _y_0);
    } else {
      return false;
    }
  }
}

function $optional_bool_eq(_a_0, _b_0) {
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
      return $bool_eq(_x_0, _y_0);
    } else {
      return false;
    }
  }
}

function $patch_eq(_a_0, _b_0) {
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
  return $Bool_and($$optional_string_eq(_at_0, _bt_0), $$Bool_and($$optional_status_eq(_ast_0, _bst_0), $$Bool_and($$optional_priority_eq(_ap_0, _bp_0), $$Bool_and($$optional_strings_eq(_ag_0, _bg_0), $$optional_bool_eq(_av_0, _bv_0)))));
}

function $payload_eq(_a_0, _b_0) {
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
      return $Bool_and((_ai_0 === _bi_0), $$Bool_and((_at_0 === _bt_0), $$Bool_and($$status_eq(_ast_0, _bst_0), $$Bool_and($$priority_eq(_ap_0, _bp_0), $$Bool_and($$strings_eq(_ag_0, _bg_0), $$bool_eq(_av_0, _bv_0))))));
    } else {
      return false;
    }
  } else if (_a_0.$ === "StatusChanged") {
    const _ai_1 = _a_0["taskId"];
    const _ast_1 = _a_0["status"];
    if (_b_0.$ === "StatusChanged") {
      const _bi_1 = _b_0["taskId"];
      const _bst_1 = _b_0["status"];
      return $Bool_and((_ai_1 === _bi_1), $$status_eq(_ast_1, _bst_1));
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
      return $Bool_and((_ai_3 === _bi_3), $$patch_eq(_ap_1, _bp_1));
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

function $event_id(_e_0) {
  const _id_0 = _e_0["id"];
  return _id_0;
}

function $event_eq(_a_0, _b_0) {
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
  return $Bool_and((_ai_0 === _bi_0), $$Bool_and((_at_0 === _bt_0), $$Bool_and((_ad_0 === _bd_0), $$Bool_and($$payload_eq(_ap_0, _bp_0), (_ac_0 === _bc_0)))));
}

function $event_le_tie(_ai_0, _bi_0, _at_0, _bt_0, _same_0) {
  if (_same_0) {
    return $String_is_le(_ai_0, _bi_0);
  } else {
    return $String_is_le(_at_0, _bt_0);
  }
}

function $event_le(_a_0, _b_0) {
  const _ai_0 = _a_0["id"];
  const _at_0 = _a_0["ts"];
  const _bi_0 = _b_0["id"];
  const _bt_0 = _b_0["ts"];
  return $event_le_tie(_ai_0, _bi_0, _at_0, _bt_0, (_at_0 === _bt_0));
}

function $ids_contains(_xs_0, _id_0) {
  if (_xs_0.$ === "Nil") {
    return false;
  } else {
    const _h_0 = _xs_0["head"];
    const _t_0 = _xs_0["tail"];
    const _x_0 = $$event_id(_h_0);
    const _x_1 = (_x_0 === _id_0);
    const _x_2 = $$ids_contains(_t_0, _id_0);
    return (_x_1 || _x_2);
  }
}

function $unique_put(_e_0, _xs_0, _exists_0) {
  if (_exists_0) {
    return _xs_0;
  } else {
    return {$: "Con", "head": _e_0, "tail": _xs_0};
  }
}

function $event_id_le(_a_0, _b_0) {
  return $String_is_le($$event_id(_a_0), $$event_id(_b_0));
}

function $scan_ids($0, $1, $2) {
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
          const _x_0 = $$event_id(_h_0);
          const _x_1 = $$event_id(_p_0);
          const _same_0 = (_x_0 === _x_1);
          return $Bool_pick($$Bool_and(_same_0, $$Bool_not($$event_eq(_h_0, _p_0))), {$: "EventConflict", "id": $$event_id(_h_0)}, $$scan_ids(_t_0, $$unique_put(_h_0, _acc_0, _same_0), {$: "Some", "value": _h_0}));
        }
      }
    }
  }
}

function $merge(_left_0, _right_0) {
  return $scan_ids($$List_sort_1($$List_append(_left_0, _right_0)), {$: "Nil"}, {$: "None"});
}

function $completion(_status_0, _instant_0) {
  if (_status_0.$ === "SDone") {
    return {$: "Some", "value": _instant_0};
  } else {
    return {$: "None"};
  }
}

function $eligible(_task_0) {
  const _private_0 = _task_0["private"];
  const _deleted_0 = _task_0["deleted"];
  return $Bool_and($$Bool_not(_private_0), $$Bool_not(_deleted_0));
}

function $chosen_notes(_notes_0, _sendNotes_0) {
  if (!_sendNotes_0) {
    return {$: "Nil"};
  } else {
    return _notes_0;
  }
}

function $project(_task_0, _sendNotes_0) {
  const _id_0 = _task_0["id"];
  const _title_0 = _task_0["title"];
  const _status_0 = _task_0["status"];
  const _priority_0 = _task_0["priority"];
  const _tags_0 = _task_0["tags"];
  const _notes_0 = _task_0["notes"];
  return {$: "ContextTask", "id": _id_0, "title": _title_0, "status": _status_0, "priority": _priority_0, "tags": _tags_0, "notes": $$chosen_notes(_notes_0, _sendNotes_0)};
}

function $context_notes(_task_0) {
  const _notes_0 = _task_0["notes"];
  return _notes_0;
}

function $task_id(_task_0) {
  const _id_0 = _task_0["id"];
  return _id_0;
}

function $task_deleted(_task_0) {
  const _deleted_0 = _task_0["deleted"];
  return _deleted_0;
}

function $task_find(_tasks_0, _id_0) {
  if (_tasks_0.$ === "Nil") {
    return {$: "None"};
  } else {
    const _h_0 = _tasks_0["head"];
    const _t_0 = _tasks_0["tail"];
    const _x_0 = $$task_id(_h_0);
    return $Bool_pick((_x_0 === _id_0), {$: "Some", "value": _h_0}, $$task_find(_t_0, _id_0));
  }
}

function $put_task(_tasks_0, _task_0) {
  if (_tasks_0.$ === "Nil") {
    return {$: "Con", "head": _task_0, "tail": {$: "Nil"}};
  } else {
    const _h_0 = _tasks_0["head"];
    const _t_0 = _tasks_0["tail"];
    const _x_0 = $$task_id(_h_0);
    const _x_1 = $$task_id(_task_0);
    return $Bool_pick((_x_0 === _x_1), {$: "Con", "head": _task_0, "tail": _t_0}, {$: "Con", "head": _h_0, "tail": $$put_task(_t_0, _task_0)});
  }
}

function $record_key_equal(_a_0, _b_0) {
  const _ad_0 = _a_0["date"];
  const _ak_0 = _a_0["kind"];
  const _bd_0 = _b_0["date"];
  const _bk_0 = _b_0["kind"];
  return $Bool_and((_ad_0 === _bd_0), (_ak_0 === _bk_0));
}

function $put_record(_records_0, _record_0) {
  if (_records_0.$ === "Nil") {
    return {$: "Con", "head": _record_0, "tail": {$: "Nil"}};
  } else {
    const _h_0 = _records_0["head"];
    const _t_0 = _records_0["tail"];
    return $Bool_pick($$record_key_equal(_h_0, _record_0), {$: "Con", "head": _record_0, "tail": _t_0}, {$: "Con", "head": _h_0, "tail": $$put_record(_t_0, _record_0)});
  }
}

function $patch_completion(_change_0, _instant_0, _previous_0) {
  if (_change_0.$ === "None") {
    return _previous_0;
  } else {
    const _s_0 = _change_0["value"];
    return $completion(_s_0, _instant_0);
  }
}

function $edit_task(_task_0, _patch_0, _instant_0) {
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
  return {$: "Task", "id": _id_0, "title": $$Maybe_default(_pt_0, _title_0), "status": $$Maybe_default(_ps_0, _status_0), "priority": $$Maybe_default(_pp_0, _priority_0), "tags": $$Maybe_default(_pg_0, _tags_0), "private": $$Maybe_default(_pv_0, _private_0), "deleted": _deleted_0, "created": _created_0, "updated": _instant_0, "completed": $$patch_completion(_ps_0, _instant_0, _completed_0), "notes": _notes_0};
}

function $note_task(_task_0, _note_0, _instant_0) {
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

function $delete_task(_task_0, _instant_0) {
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

function $apply_payload(_task_0, _payload_0, _id_0, _instant_0) {
  if (_payload_0.$ === "StatusChanged") {
    const _status_0 = _payload_0["status"];
    return $edit_task(_task_0, {$: "Patch", "title": {$: "None"}, "status": {$: "Some", "value": _status_0}, "priority": {$: "None"}, "tags": {$: "None"}, "private": {$: "None"}}, _instant_0);
  } else if (_payload_0.$ === "Noted") {
    const _text_0 = _payload_0["text"];
    return $note_task(_task_0, {$: "Note", "id": _id_0, "ts": _instant_0, "text": _text_0}, _instant_0);
  } else if (_payload_0.$ === "Edited") {
    const _patch_0 = _payload_0["patch"];
    return $edit_task(_task_0, _patch_0, _instant_0);
  } else if (_payload_0.$ === "Deleted") {
    return $delete_task(_task_0, _instant_0);
  } else {
    return _task_0;
  }
}

function $empty_state() {
  return {$: "State", "tasks": {$: "Nil"}, "summaries": {$: "Nil"}, "reports": {$: "Nil"}, "diagnostics": {$: "Nil"}, "complete": true};
}

function $diagnostic(_state_0, _issue_0) {
  const _tasks_0 = _state_0["tasks"];
  const _summaries_0 = _state_0["summaries"];
  const _reports_0 = _state_0["reports"];
  const _issues_0 = _state_0["diagnostics"];
  return {$: "State", "tasks": _tasks_0, "summaries": _summaries_0, "reports": _reports_0, "diagnostics": $$List_append(_issues_0, {$: "Con", "head": _issue_0, "tail": {$: "Nil"}}), "complete": false};
}

function $state_put(_state_0, _task_0) {
  const _tasks_0 = _state_0["tasks"];
  const _summaries_0 = _state_0["summaries"];
  const _reports_0 = _state_0["reports"];
  const _issues_0 = _state_0["diagnostics"];
  const _complete_0 = _state_0["complete"];
  return {$: "State", "tasks": $$put_task(_tasks_0, _task_0), "summaries": _summaries_0, "reports": _reports_0, "diagnostics": _issues_0, "complete": _complete_0};
}

function $state_task(_state_0, _id_0) {
  const _tasks_0 = _state_0["tasks"];
  return $task_find(_tasks_0, _id_0);
}

function $create_found(_state_0, _task_0, _eventId_0, _taskId_0, _previous_0) {
  if (_previous_0.$ === "None") {
    return $state_put(_state_0, _task_0);
  } else {
    return $diagnostic(_state_0, {$: "DuplicateCreate", "eventId": _eventId_0, "taskId": _taskId_0});
  }
}

function $update_live(_state_0, _task_0, _payload_0, _id_0, _instant_0, _taskId_0, _deleted_0) {
  if (!_deleted_0) {
    return $state_put(_state_0, $$apply_payload(_task_0, _payload_0, _id_0, _instant_0));
  } else {
    return $diagnostic(_state_0, {$: "AfterDelete", "eventId": _id_0, "taskId": _taskId_0});
  }
}

function $update_found(_state_0, _payload_0, _id_0, _instant_0, _taskId_0, _found_0) {
  if (_found_0.$ === "None") {
    return $diagnostic(_state_0, {$: "MissingTask", "eventId": _id_0, "taskId": _taskId_0});
  } else {
    const _task_0 = _found_0["value"];
    return $update_live(_state_0, _task_0, _payload_0, _id_0, _instant_0, _taskId_0, $$task_deleted(_task_0));
  }
}

function $update_existing(_state_0, _payload_0, _id_0, _instant_0, _taskId_0) {
  return $update_found(_state_0, _payload_0, _id_0, _instant_0, _taskId_0, $$state_task(_state_0, _taskId_0));
}

function $apply_summary(_state_0, _record_0) {
  const _tasks_0 = _state_0["tasks"];
  const _summaries_0 = _state_0["summaries"];
  const _reports_0 = _state_0["reports"];
  const _issues_0 = _state_0["diagnostics"];
  const _complete_0 = _state_0["complete"];
  return {$: "State", "tasks": _tasks_0, "summaries": $$put_record(_summaries_0, _record_0), "reports": _reports_0, "diagnostics": _issues_0, "complete": _complete_0};
}

function $apply_report(_state_0, _record_0) {
  const _tasks_0 = _state_0["tasks"];
  const _summaries_0 = _state_0["summaries"];
  const _reports_0 = _state_0["reports"];
  const _issues_0 = _state_0["diagnostics"];
  const _complete_0 = _state_0["complete"];
  return {$: "State", "tasks": _tasks_0, "summaries": _summaries_0, "reports": $$put_record(_reports_0, _record_0), "diagnostics": _issues_0, "complete": _complete_0};
}

function $apply_event(_state_0, _event_0) {
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
    return $create_found(_state_0, {$: "Task", "id": _taskId_0, "title": _title_0, "status": _status_0, "priority": _priority_0, "tags": _tags_0, "private": _private_0, "deleted": false, "created": _ts_0, "updated": _ts_0, "completed": $$completion(_status_0, _ts_0), "notes": {$: "Nil"}}, _id_0, _taskId_0, $$state_task(_state_0, _taskId_0));
  } else if (_t_0.$ === "StatusChanged") {
    const _taskId_1 = _t_0["taskId"];
    const _status_1 = _t_0["status"];
    return $update_existing(_state_0, {$: "StatusChanged", "taskId": _taskId_1, "status": _status_1}, _id_0, _ts_0, _taskId_1);
  } else if (_t_0.$ === "Noted") {
    const _taskId_2 = _t_0["taskId"];
    const _text_0 = _t_0["text"];
    return $update_existing(_state_0, {$: "Noted", "taskId": _taskId_2, "text": _text_0}, _id_0, _ts_0, _taskId_2);
  } else if (_t_0.$ === "Edited") {
    const _taskId_3 = _t_0["taskId"];
    const _patch_0 = _t_0["patch"];
    return $update_existing(_state_0, {$: "Edited", "taskId": _taskId_3, "patch": _patch_0}, _id_0, _ts_0, _taskId_3);
  } else if (_t_0.$ === "Deleted") {
    const _taskId_4 = _t_0["taskId"];
    return $update_existing(_state_0, {$: "Deleted", "taskId": _taskId_4}, _id_0, _ts_0, _taskId_4);
  } else if (_t_0.$ === "SummarySet") {
    const _date_0 = _t_0["date"];
    const _kind_0 = _t_0["kind"];
    const _body_0 = _t_0["body"];
    return $apply_summary(_state_0, {$: "Recorded", "id": _id_0, "ts": _ts_0, "date": _date_0, "kind": _kind_0, "body": _body_0});
  } else if (_t_0.$ === "StandupSet") {
    const _date_1 = _t_0["date"];
    const _kind_1 = _t_0["kind"];
    const _text_1 = _t_0["text"];
    return $apply_report(_state_0, {$: "Recorded", "id": _id_0, "ts": _ts_0, "date": _date_1, "kind": _kind_1, "body": _text_1});
  } else {
    const _kind_2 = _t_0["kind"];
    return $diagnostic(_state_0, {$: "Unsupported", "eventId": _id_0, "kind": _kind_2});
  }
}

function $fold_sorted($0, $1) {
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
        $1 = $$apply_event(_state_0, _h_0);
        continue;
      }
    }
  }
}

function $replay_merged(_result_0) {
  if (_result_0.$ === "EventConflict") {
    const _id_0 = _result_0["id"];
    return {$: "ReplayConflict", "id": _id_0};
  } else {
    const _events_0 = _result_0["events"];
    return {$: "Replayed", "state": $$fold_sorted(_events_0, $$empty_state())};
  }
}

function $replay(_events_0) {
  return $replay_merged($$merge(_events_0, {$: "Nil"}));
}

function $reconcile(_covered_0, _incoming_0) {
  return $replay_merged($$merge(_covered_0, _incoming_0));
}

function $complete(_state_0) {
  const _complete_0 = _state_0["complete"];
  return _complete_0;
}

function $context_put(_task_0, _rest_0, _sendNotes_0, _keep_0) {
  if (!_keep_0) {
    return _rest_0;
  } else {
    return {$: "Con", "head": $$project(_task_0, _sendNotes_0), "tail": _rest_0};
  }
}

function $context_tasks(_tasks_0, _sendNotes_0) {
  if (_tasks_0.$ === "Nil") {
    return {$: "Nil"};
  } else {
    const _h_0 = _tasks_0["head"];
    const _t_0 = _tasks_0["tail"];
    return $context_put(_h_0, $$context_tasks(_t_0, _sendNotes_0), _sendNotes_0, $$eligible(_h_0));
  }
}

function $context_state(_safe_0, _state_0, _sendNotes_0) {
  if (!_safe_0) {
    return {$: "Nil"};
  } else {
    const _tasks_0 = _state_0["tasks"];
    return $context_tasks(_tasks_0, _sendNotes_0);
  }
}

function $context(_state_0, _sendNotes_0) {
  return $context_state($$complete(_state_0), _state_0, _sendNotes_0);
}

function $valid_text(_text_0, _bound_0) {
  return $Bool_and($$Bool_not($$String_is_empty($$String_trim(_text_0))), $$Nat_is_le([...str_out(_text_0)].length, _bound_0));
}

function $valid_tags(_tags_0) {
  if (_tags_0.$ === "Nil") {
    return true;
  } else {
    const _h_0 = _tags_0["head"];
    const _t_0 = _tags_0["tail"];
    return $Bool_and($$valid_text(_h_0, 64), $$valid_tags(_t_0));
  }
}

function $valid_optional_title(_value_0) {
  if (_value_0.$ === "None") {
    return true;
  } else {
    const _text_0 = _value_0["value"];
    return $valid_text(_text_0, 200);
  }
}

function $valid_optional_tags(_value_0) {
  if (_value_0.$ === "None") {
    return true;
  } else {
    const _tags_0 = _value_0["value"];
    return $Bool_and($$Nat_is_le($$List_length(_tags_0), 50), $$valid_tags(_tags_0));
  }
}

function $valid_patch(_patch_0) {
  const _title_0 = _patch_0["title"];
  const _tags_0 = _patch_0["tags"];
  return $Bool_and($$valid_optional_title(_title_0), $$valid_optional_tags(_tags_0));
}

function $live(_found_0) {
  if (_found_0.$ === "None") {
    return false;
  } else {
    const _task_0 = _found_0["value"];
    return $Bool_not($$task_deleted(_task_0));
  }
}

function $absent(_found_0) {
  if (_found_0.$ === "None") {
    return true;
  } else {
    return false;
  }
}

function $valid_kind(_kind_0) {
  const _x_0 = (_kind_0 === "morning");
  const _x_1 = (_kind_0 === "evening");
  return (_x_0 || _x_1);
}

function $command_valid(_state_0, _payload_0) {
  if (_payload_0.$ === "Created") {
    const _taskId_0 = _payload_0["taskId"];
    const _title_0 = _payload_0["title"];
    const _tags_0 = _payload_0["tags"];
    return $Bool_and($$absent($$state_task(_state_0, _taskId_0)), $$Bool_and($$valid_text(_title_0, 200), $$Bool_and($$Nat_is_le($$List_length(_tags_0), 50), $$valid_tags(_tags_0))));
  } else if (_payload_0.$ === "StatusChanged") {
    const _taskId_1 = _payload_0["taskId"];
    return $live($$state_task(_state_0, _taskId_1));
  } else if (_payload_0.$ === "Noted") {
    const _taskId_2 = _payload_0["taskId"];
    const _text_0 = _payload_0["text"];
    return $Bool_and($$live($$state_task(_state_0, _taskId_2)), $$valid_text(_text_0, (20000 )));
  } else if (_payload_0.$ === "Edited") {
    const _taskId_3 = _payload_0["taskId"];
    const _patch_0 = _payload_0["patch"];
    return $Bool_and($$live($$state_task(_state_0, _taskId_3)), $$valid_patch(_patch_0));
  } else if (_payload_0.$ === "Deleted") {
    const _taskId_4 = _payload_0["taskId"];
    return $live($$state_task(_state_0, _taskId_4));
  } else if (_payload_0.$ === "SummarySet") {
    const _date_0 = _payload_0["date"];
    const _kind_0 = _payload_0["kind"];
    const _body_0 = _payload_0["body"];
    return $Bool_and($$Bool_not($$String_is_empty(_date_0)), $$Bool_and($$valid_kind(_kind_0), $$Bool_not($$String_is_empty(_body_0))));
  } else if (_payload_0.$ === "StandupSet") {
    const _date_1 = _payload_0["date"];
    const _kind_1 = _payload_0["kind"];
    const _text_1 = _payload_0["text"];
    return $Bool_and($$Bool_not($$String_is_empty(_date_1)), $$Bool_and($$valid_kind(_kind_1), $$valid_text(_text_1, (20000 ))));
  } else {
    return false;
  }
}

function $stage_valid(_event_0, _valid_0) {
  if (!_valid_0) {
    return {$: "StageRejected", "reason": "invalid command or unavailable task"};
  } else {
    return {$: "StageAccepted", "event": _event_0};
  }
}

function $stage_state(_result_0, _event_0) {
  if (_result_0.$ === "ReplayConflict") {
    return {$: "StageRejected", "reason": "event ID content conflict"};
  } else {
    const _state_0 = _result_0["state"];
    const _id_1 = _event_0["id"];
    const _ts_0 = _event_0["ts"];
    const _day_0 = _event_0["day"];
    const _payload_0 = _event_0["payload"];
    const _canonical_0 = _event_0["canonical"];
    return $stage_valid({$: "Ev", "id": _id_1, "ts": _ts_0, "day": _day_0, "payload": _payload_0, "canonical": _canonical_0}, $$Bool_and($$complete(_state_0), $$Bool_and($$command_valid(_state_0, _payload_0), $$Bool_and($$Bool_not($$String_is_empty(_id_1)), $$Bool_and($$Bool_not($$String_is_empty(_ts_0)), $$Bool_not($$String_is_empty(_day_0)))))));
  }
}

function $stage_unique(_event_0, _existing_0, _duplicate_0) {
  if (_duplicate_0) {
    return {$: "StageRejected", "reason": "event ID already exists"};
  } else {
    return $stage_state($$replay(_existing_0), _event_0);
  }
}

function $stage(_events_0, _event_0) {
  return $stage_unique(_event_0, _events_0, $$ids_contains(_events_0, $$event_id(_event_0)));
}

function $schema_allowed(_version_0) {
  const _x_0 = (_version_0 === 1);
  const _x_1 = (_version_0 === 2);
  return (_x_0 || _x_1);
}

function $exact_contains(_events_0, _event_0) {
  if (_events_0.$ === "Nil") {
    return false;
  } else {
    const _h_0 = _events_0["head"];
    const _t_0 = _events_0["tail"];
    const _x_0 = $$event_eq(_h_0, _event_0);
    const _x_1 = $$exact_contains(_t_0, _event_0);
    return (_x_0 || _x_1);
  }
}

function $acknowledge_put(_event_0, _rest_0, _acknowledged_0) {
  if (_acknowledged_0) {
    return _rest_0;
  } else {
    return {$: "Con", "head": _event_0, "tail": _rest_0};
  }
}

function $acknowledge_success(_pending_0, _committed_0) {
  if (_pending_0.$ === "Nil") {
    return {$: "Nil"};
  } else {
    const _h_0 = _pending_0["head"];
    const _t_0 = _pending_0["tail"];
    return $acknowledge_put(_h_0, $$acknowledge_success(_t_0, _committed_0), $$exact_contains(_committed_0, _h_0));
  }
}

function $acknowledge(_pending_0, _committed_0, _success_0) {
  if (!_success_0) {
    return _pending_0;
  } else {
    return $acknowledge_success(_pending_0, _committed_0);
  }
}

function $eligible_found(_found_0) {
  if (_found_0.$ === "None") {
    return false;
  } else {
    const _task_0 = _found_0["value"];
    return $eligible(_task_0);
  }
}

function $eligible_target(_state_0, _id_0) {
  return $Bool_and($$complete(_state_0), $$eligible_found($$state_task(_state_0, _id_0)));
}

function $history_chosen(_event_0, _allowed_0) {
  if (!_allowed_0) {
    return {$: "None"};
  } else {
    return {$: "Some", "value": _event_0};
  }
}

function $history_patch(_patch_0, _id_0, _ts_0, _day_0, _taskId_0) {
  const _title_0 = _patch_0["title"];
  const _status_0 = _patch_0["status"];
  return {$: "ContextEvent", "id": _id_0, "ts": _ts_0, "day": _day_0, "taskId": _taskId_0, "kind": "task.edit", "title": $$Maybe_default(_title_0, ""), "status": _status_0, "text": ""};
}

function $history_payload(_payload_0, _state_0, _id_0, _ts_0, _day_0, _sendNotes_0) {
  if (_payload_0.$ === "Created") {
    const _taskId_0 = _payload_0["taskId"];
    const _title_0 = _payload_0["title"];
    const _status_0 = _payload_0["status"];
    return $history_chosen({$: "ContextEvent", "id": _id_0, "ts": _ts_0, "day": _day_0, "taskId": _taskId_0, "kind": "task.create", "title": _title_0, "status": {$: "Some", "value": _status_0}, "text": ""}, $$eligible_target(_state_0, _taskId_0));
  } else if (_payload_0.$ === "StatusChanged") {
    const _taskId_1 = _payload_0["taskId"];
    const _status_1 = _payload_0["status"];
    return $history_chosen({$: "ContextEvent", "id": _id_0, "ts": _ts_0, "day": _day_0, "taskId": _taskId_1, "kind": "task.status", "title": "", "status": {$: "Some", "value": _status_1}, "text": ""}, $$eligible_target(_state_0, _taskId_1));
  } else if (_payload_0.$ === "Noted") {
    const _taskId_2 = _payload_0["taskId"];
    const _text_0 = _payload_0["text"];
    return $history_chosen({$: "ContextEvent", "id": _id_0, "ts": _ts_0, "day": _day_0, "taskId": _taskId_2, "kind": "task.note", "title": "", "status": {$: "None"}, "text": _text_0}, $$Bool_and(_sendNotes_0, $$eligible_target(_state_0, _taskId_2)));
  } else if (_payload_0.$ === "Edited") {
    const _taskId_3 = _payload_0["taskId"];
    const _patch_0 = _payload_0["patch"];
    return $history_chosen($$history_patch(_patch_0, _id_0, _ts_0, _day_0, _taskId_3), $$eligible_target(_state_0, _taskId_3));
  } else {
    return {$: "None"};
  }
}

function $in_window(_day_0, _startDay_0, _endDay_0) {
  return $Bool_and($$String_is_ge(_day_0, _startDay_0), $$String_is_le(_day_0, _endDay_0));
}

function $history_window(_event_0, _allowed_0) {
  if (!_allowed_0) {
    return {$: "None"};
  } else {
    return _event_0;
  }
}

function $history_event(_event_0, _state_0, _sendNotes_0, _startDay_0, _endDay_0) {
  const _id_0 = _event_0["id"];
  const _ts_0 = _event_0["ts"];
  const _day_0 = _event_0["day"];
  const _payload_0 = _event_0["payload"];
  return $history_window($$history_payload(_payload_0, _state_0, _id_0, _ts_0, _day_0, _sendNotes_0), $$in_window(_day_0, _startDay_0, _endDay_0));
}

function $history_put(_chosen_0, _rest_0) {
  if (_chosen_0.$ === "None") {
    return _rest_0;
  } else {
    const _event_0 = _chosen_0["value"];
    return {$: "Con", "head": _event_0, "tail": _rest_0};
  }
}

function $context_events_go(_events_0, _state_0, _sendNotes_0, _startDay_0, _endDay_0) {
  if (_events_0.$ === "Nil") {
    return {$: "Nil"};
  } else {
    const _h_0 = _events_0["head"];
    const _t_0 = _events_0["tail"];
    return $history_put($$history_event(_h_0, _state_0, _sendNotes_0, _startDay_0, _endDay_0), $$context_events_go(_t_0, _state_0, _sendNotes_0, _startDay_0, _endDay_0));
  }
}

function $context_events(_state_0, _events_0, _sendNotes_0, _startDay_0, _endDay_0) {
  return $context_events_go(_events_0, _state_0, _sendNotes_0, _startDay_0, _endDay_0);
}

function $proposal_target_valid(_state_0, _payload_0) {
  if (_payload_0.$ === "Created") {
    return true;
  } else if (_payload_0.$ === "StatusChanged") {
    const _taskId_1 = _payload_0["taskId"];
    return $eligible_target(_state_0, _taskId_1);
  } else if (_payload_0.$ === "Noted") {
    const _taskId_2 = _payload_0["taskId"];
    return $eligible_target(_state_0, _taskId_2);
  } else if (_payload_0.$ === "Edited") {
    const _taskId_3 = _payload_0["taskId"];
    return $eligible_target(_state_0, _taskId_3);
  } else {
    return false;
  }
}

function $proposal_state(_result_0, _events_0, _event_0) {
  if (_result_0.$ === "ReplayConflict") {
    return {$: "StageRejected", "reason": "event ID content conflict"};
  } else {
    const _state_0 = _result_0["state"];
    const _id_1 = _event_0["id"];
    const _ts_0 = _event_0["ts"];
    const _day_0 = _event_0["day"];
    const _payload_0 = _event_0["payload"];
    const _canonical_0 = _event_0["canonical"];
    return $Bool_pick($$proposal_target_valid(_state_0, _payload_0), $$stage(_events_0, {$: "Ev", "id": _id_1, "ts": _ts_0, "day": _day_0, "payload": _payload_0, "canonical": _canonical_0}), {$: "StageRejected", "reason": "proposal target is not eligible"});
  }
}

function $proposal_stage(_events_0, _event_0) {
  return $proposal_state($$replay(_events_0), _events_0, _event_0);
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
      return {$: "Con", "head": $$List_sort_pair(_x_0, _y_0, $$event_le(_x_0, _y_0)), "tail": $$List_sort_pairs_0(_t_1)};
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
      return {$: "Con", "head": $$List_sort_pair(_x_0, _y_0, $$event_id_le(_x_0, _y_0)), "tail": $$List_sort_pairs_1(_t_1)};
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
            $1 = $$List_merge_step(_acc_1, _x_0, _xt_0, _y_1, _yt_1, $$event_le(_x_0, _y_1));
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
            $1 = $$List_merge_step(_acc_1, _x_0, _xt_0, _y_1, _yt_1, $$event_id_le(_x_0, _y_1));
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
const $$strings_eq = $strings_eq;
const $$optional_string_eq = $optional_string_eq;
const $$optional_status_eq = $optional_status_eq;
const $$optional_priority_eq = $optional_priority_eq;
const $$optional_strings_eq = $optional_strings_eq;
const $$optional_bool_eq = $optional_bool_eq;
const $$Bool_and = $Bool_and;
const $$status_eq = $status_eq;
const $$priority_eq = $priority_eq;
const $$bool_eq = $bool_eq;
const $$patch_eq = $patch_eq;
const $$payload_eq = $payload_eq;
const $$event_id = $event_id;
const $$ids_contains = $ids_contains;
const $$List_sort_0 = $List_sort_0;
const $$event_eq = $event_eq;
const $$Bool_not = $Bool_not;
const $$unique_put = $unique_put;
const $$scan_ids = $scan_ids;
const $$List_append = $List_append;
const $$List_sort_1 = $List_sort_1;
const $$chosen_notes = $chosen_notes;
const $$task_id = $task_id;
const $$task_find = $task_find;
const $$put_task = $put_task;
const $$record_key_equal = $record_key_equal;
const $$put_record = $put_record;
const $$Maybe_default = $Maybe_default;
const $$patch_completion = $patch_completion;
const $$apply_payload = $apply_payload;
const $$task_deleted = $task_deleted;
const $$state_task = $state_task;
const $$completion = $completion;
const $$apply_event = $apply_event;
const $$empty_state = $empty_state;
const $$fold_sorted = $fold_sorted;
const $$merge = $merge;
const $$project = $project;
const $$context_tasks = $context_tasks;
const $$eligible = $eligible;
const $$complete = $complete;
const $$String_trim = $String_trim;
const $$String_is_empty = $String_is_empty;
const $$Nat_is_le = $Nat_is_le;
const $$valid_text = $valid_text;
const $$valid_tags = $valid_tags;
const $$List_length = $List_length;
const $$valid_optional_title = $valid_optional_title;
const $$valid_optional_tags = $valid_optional_tags;
const $$absent = $absent;
const $$live = $live;
const $$valid_patch = $valid_patch;
const $$valid_kind = $valid_kind;
const $$command_valid = $command_valid;
const $$replay = $replay;
const $$exact_contains = $exact_contains;
const $$acknowledge_success = $acknowledge_success;
const $$eligible_found = $eligible_found;
const $$eligible_target = $eligible_target;
const $$history_patch = $history_patch;
const $$String_is_ge = $String_is_ge;
const $$String_is_le = $String_is_le;
const $$history_payload = $history_payload;
const $$in_window = $in_window;
const $$history_event = $history_event;
const $$context_events_go = $context_events_go;
const $$proposal_target_valid = $proposal_target_valid;
const $$stage = $stage;
const $$String_order = $String_order;
const $$List_sort_pairs_0 = $List_sort_pairs_0;
const $$List_sort_pairs_1 = $List_sort_pairs_1;
const $$String_trim_start = $String_trim_start;
const $$List_sort_pass_0 = $List_sort_pass_0;
const $$event_le = $event_le;
const $$List_sort_pair = $List_sort_pair;
const $$List_sort_pass_1 = $List_sort_pass_1;
const $$event_id_le = $event_id_le;
const $$String_reverse = $String_reverse;
const $$Char_is_space = $Char_is_space;
const $$List_concat = $List_concat;
const $$List_merge_go_0 = $List_merge_go_0;
const $$List_merge_go_1 = $List_merge_go_1;
const $$List_merge_step = $List_merge_step;export default {
  "status_eq": run_lib((a0,a1) => run_loop($status_eq(a0,a1)), 2),
  "priority_eq": run_lib((a0,a1) => run_loop($priority_eq(a0,a1)), 2),
  "bool_eq": run_lib((a0,a1) => run_loop($bool_eq(a0,a1)), 2),
  "strings_eq": run_lib((a0,a1) => run_loop($strings_eq(a0,a1)), 2),
  "optional_string_eq": run_lib((a0,a1) => run_loop($optional_string_eq(a0,a1)), 2),
  "optional_status_eq": run_lib((a0,a1) => run_loop($optional_status_eq(a0,a1)), 2),
  "optional_priority_eq": run_lib((a0,a1) => run_loop($optional_priority_eq(a0,a1)), 2),
  "optional_strings_eq": run_lib((a0,a1) => run_loop($optional_strings_eq(a0,a1)), 2),
  "optional_bool_eq": run_lib((a0,a1) => run_loop($optional_bool_eq(a0,a1)), 2),
  "patch_eq": run_lib((a0,a1) => run_loop($patch_eq(a0,a1)), 2),
  "payload_eq": run_lib((a0,a1) => run_loop($payload_eq(a0,a1)), 2),
  "event_id": run_lib((a0) => str_out(run_loop($event_id(a0))), 1),
  "event_eq": run_lib((a0,a1) => run_loop($event_eq(a0,a1)), 2),
  "event_le_tie": run_lib((a0,a1,a2,a3,a4) => run_loop($event_le_tie(str_in(a0),str_in(a1),str_in(a2),str_in(a3),a4)), 5),
  "event_le": run_lib((a0,a1) => run_loop($event_le(a0,a1)), 2),
  "ids_contains": run_lib((a0,a1) => run_loop($ids_contains(a0,str_in(a1))), 2),
  "unique_put": run_lib((a0,a1,a2) => run_loop($unique_put(a0,a1,a2)), 3),
  "event_id_le": run_lib((a0,a1) => run_loop($event_id_le(a0,a1)), 2),
  "scan_ids": run_lib((a0,a1,a2) => run_loop($scan_ids(a0,a1,a2)), 3),
  "merge": run_lib((a0,a1) => run_loop($merge(a0,a1)), 2),
  "completion": run_lib((a0,a1) => run_loop($completion(a0,str_in(a1))), 2),
  "eligible": run_lib((a0) => run_loop($eligible(a0)), 1),
  "chosen_notes": run_lib((a0,a1) => run_loop($chosen_notes(a0,a1)), 2),
  "project": run_lib((a0,a1) => run_loop($project(a0,a1)), 2),
  "context_notes": run_lib((a0) => run_loop($context_notes(a0)), 1),
  "task_id": run_lib((a0) => str_out(run_loop($task_id(a0))), 1),
  "task_deleted": run_lib((a0) => run_loop($task_deleted(a0)), 1),
  "task_find": run_lib((a0,a1) => run_loop($task_find(a0,str_in(a1))), 2),
  "put_task": run_lib((a0,a1) => run_loop($put_task(a0,a1)), 2),
  "record_key_equal": run_lib((a0,a1) => run_loop($record_key_equal(a0,a1)), 2),
  "put_record": run_lib((a0,a1) => run_loop($put_record(a0,a1)), 2),
  "patch_completion": run_lib((a0,a1,a2) => run_loop($patch_completion(a0,str_in(a1),a2)), 3),
  "edit_task": run_lib((a0,a1,a2) => run_loop($edit_task(a0,a1,str_in(a2))), 3),
  "note_task": run_lib((a0,a1,a2) => run_loop($note_task(a0,a1,str_in(a2))), 3),
  "delete_task": run_lib((a0,a1) => run_loop($delete_task(a0,str_in(a1))), 2),
  "apply_payload": run_lib((a0,a1,a2,a3) => run_loop($apply_payload(a0,a1,str_in(a2),str_in(a3))), 4),
  "empty_state": run_lib(() => run_loop($empty_state()), 0),
  "diagnostic": run_lib((a0,a1) => run_loop($diagnostic(a0,a1)), 2),
  "state_put": run_lib((a0,a1) => run_loop($state_put(a0,a1)), 2),
  "state_task": run_lib((a0,a1) => run_loop($state_task(a0,str_in(a1))), 2),
  "create_found": run_lib((a0,a1,a2,a3,a4) => run_loop($create_found(a0,a1,str_in(a2),str_in(a3),a4)), 5),
  "update_live": run_lib((a0,a1,a2,a3,a4,a5,a6) => run_loop($update_live(a0,a1,a2,str_in(a3),str_in(a4),str_in(a5),a6)), 7),
  "update_found": run_lib((a0,a1,a2,a3,a4,a5) => run_loop($update_found(a0,a1,str_in(a2),str_in(a3),str_in(a4),a5)), 6),
  "update_existing": run_lib((a0,a1,a2,a3,a4) => run_loop($update_existing(a0,a1,str_in(a2),str_in(a3),str_in(a4))), 5),
  "apply_summary": run_lib((a0,a1) => run_loop($apply_summary(a0,a1)), 2),
  "apply_report": run_lib((a0,a1) => run_loop($apply_report(a0,a1)), 2),
  "apply_event": run_lib((a0,a1) => run_loop($apply_event(a0,a1)), 2),
  "fold_sorted": run_lib((a0,a1) => run_loop($fold_sorted(a0,a1)), 2),
  "replay_merged": run_lib((a0) => run_loop($replay_merged(a0)), 1),
  "replay": run_lib((a0) => run_loop($replay(a0)), 1),
  "reconcile": run_lib((a0,a1) => run_loop($reconcile(a0,a1)), 2),
  "complete": run_lib((a0) => run_loop($complete(a0)), 1),
  "context_put": run_lib((a0,a1,a2,a3) => run_loop($context_put(a0,a1,a2,a3)), 4),
  "context_tasks": run_lib((a0,a1) => run_loop($context_tasks(a0,a1)), 2),
  "context_state": run_lib((a0,a1,a2) => run_loop($context_state(a0,a1,a2)), 3),
  "context": run_lib((a0,a1) => run_loop($context(a0,a1)), 2),
  "valid_text": run_lib((a0,a1) => run_loop($valid_text(str_in(a0),nat_in(a1))), 2),
  "valid_tags": run_lib((a0) => run_loop($valid_tags(a0)), 1),
  "valid_optional_title": run_lib((a0) => run_loop($valid_optional_title(a0)), 1),
  "valid_optional_tags": run_lib((a0) => run_loop($valid_optional_tags(a0)), 1),
  "valid_patch": run_lib((a0) => run_loop($valid_patch(a0)), 1),
  "live": run_lib((a0) => run_loop($live(a0)), 1),
  "absent": run_lib((a0) => run_loop($absent(a0)), 1),
  "valid_kind": run_lib((a0) => run_loop($valid_kind(str_in(a0))), 1),
  "command_valid": run_lib((a0,a1) => run_loop($command_valid(a0,a1)), 2),
  "stage_valid": run_lib((a0,a1) => run_loop($stage_valid(a0,a1)), 2),
  "stage_state": run_lib((a0,a1) => run_loop($stage_state(a0,a1)), 2),
  "stage_unique": run_lib((a0,a1,a2) => run_loop($stage_unique(a0,a1,a2)), 3),
  "stage": run_lib((a0,a1) => run_loop($stage(a0,a1)), 2),
  "schema_allowed": run_lib((a0) => run_loop($schema_allowed(a0)), 1),
  "exact_contains": run_lib((a0,a1) => run_loop($exact_contains(a0,a1)), 2),
  "acknowledge_put": run_lib((a0,a1,a2) => run_loop($acknowledge_put(a0,a1,a2)), 3),
  "acknowledge_success": run_lib((a0,a1) => run_loop($acknowledge_success(a0,a1)), 2),
  "acknowledge": run_lib((a0,a1,a2) => run_loop($acknowledge(a0,a1,a2)), 3),
  "eligible_found": run_lib((a0) => run_loop($eligible_found(a0)), 1),
  "eligible_target": run_lib((a0,a1) => run_loop($eligible_target(a0,str_in(a1))), 2),
  "history_chosen": run_lib((a0,a1) => run_loop($history_chosen(a0,a1)), 2),
  "history_patch": run_lib((a0,a1,a2,a3,a4) => run_loop($history_patch(a0,str_in(a1),str_in(a2),str_in(a3),str_in(a4))), 5),
  "history_payload": run_lib((a0,a1,a2,a3,a4,a5) => run_loop($history_payload(a0,a1,str_in(a2),str_in(a3),str_in(a4),a5)), 6),
  "in_window": run_lib((a0,a1,a2) => run_loop($in_window(str_in(a0),str_in(a1),str_in(a2))), 3),
  "history_window": run_lib((a0,a1) => run_loop($history_window(a0,a1)), 2),
  "history_event": run_lib((a0,a1,a2,a3,a4) => run_loop($history_event(a0,a1,a2,str_in(a3),str_in(a4))), 5),
  "history_put": run_lib((a0,a1) => run_loop($history_put(a0,a1)), 2),
  "context_events_go": run_lib((a0,a1,a2,a3,a4) => run_loop($context_events_go(a0,a1,a2,str_in(a3),str_in(a4))), 5),
  "context_events": run_lib((a0,a1,a2,a3,a4) => run_loop($context_events(a0,a1,a2,str_in(a3),str_in(a4))), 5),
  "proposal_target_valid": run_lib((a0,a1) => run_loop($proposal_target_valid(a0,a1)), 2),
  "proposal_state": run_lib((a0,a1,a2) => run_loop($proposal_state(a0,a1,a2)), 3),
  "proposal_stage": run_lib((a0,a1) => run_loop($proposal_stage(a0,a1)), 2),
};
