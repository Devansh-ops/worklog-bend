/**
 * board.js — the Kanban board.
 *
 * Every interaction here stages an event locally; none of them touch the network.
 * Dragging a card produces a task.status event, which is what makes the repo history
 * read as a record of work rather than a series of file overwrites.
 */
import { STATUSES, PRIORITIES, statusLabel, makeEvent, newTaskId } from '../store.js';
import { el, clear, dialog, confirm, age, shortTime, plural } from './dom.js';
import { ownerProjection } from '../domain.js';

/** Cards sort by priority then recency, so what matters is at the top of a column. */

export class BoardView {
  /**
   * @param {object} app the shell: {tasks, stage(...events), refresh(), search}
   */
  constructor(app) {
    this.app = app;
    this.root = el('div', { class: 'view' });
    this.dragId = null;
    this.flash = null;         // task to highlight after a jump from a summary bullet
  }

  render() {
    const state = this.app.state;
    const projection = ownerProjection(state.events, this.app.search || '', false, state.compiled);
    clear(this.root);

    this.root.append(el('div', { class: 'board' }, STATUSES.map((s) => this.column(s, projection.columns[s.id]))));

    if (!this.app.tasks.length) {
      this.root.append(el('div', { class: 'card', style: 'margin-top:14px' },
        el('h2', { text: 'No tasks yet' }),
        el('p', { class: 'sub' }, 'Add one with the button in the header, or write what you did in ',
          el('strong', { text: 'Brain dump' }), ' and let the AI lay out the board for you.')));
    }

    if (this.flash) {
      const card = Array.from(this.root.querySelectorAll('[data-task]')).find(node => node.dataset.task === this.flash);
      if (card) {
        card.classList.add('flash');
        card.scrollIntoView({ block: 'center', behavior: 'smooth' });
      }
      this.flash = null;
    }
    return this.root;
  }

  column(status, tasks) {
    const mine = tasks;

    const col = el('div', {
      class: 'column',
      dataset: { status: status.id },
      on: {
        dragover: (e) => { if (this.dragId) { e.preventDefault(); col.classList.add('drag-over'); } },
        dragleave: () => col.classList.remove('drag-over'),
        drop: (e) => { e.preventDefault(); col.classList.remove('drag-over'); this.move(this.dragId, status.id); },
      },
    },
    el('h3', {}, status.label, el('span', { class: 'count', text: String(mine.length) })),
    mine.length ? mine.map((t) => this.card(t)) : el('div', { class: 'empty', text: '—' }));

    return col;
  }

  card(t) {
    const node = el('div', {
      class: `task p-${t.priority}`,
      draggable: true,
      tabindex: '0',
      dataset: { task: t.id },
      role: 'button',
      'aria-label': `${t.title}, ${statusLabel(t.status)}`,
      on: {
        dragstart: (e) => { this.dragId = t.id; node.classList.add('dragging'); e.dataTransfer.effectAllowed = 'move'; e.dataTransfer.setData('text/plain', t.id); },
        dragend: () => { this.dragId = null; node.classList.remove('dragging'); },
        click: () => this.open(t.id),
        keydown: (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); this.open(t.id); } },
      },
    },
    el('div', { class: 'title', text: t.title }),
    el('div', { class: 'meta' },
      el('span', { class: 'id', text: t.id }),
      t.private ? el('span', { class: 'tag private', text: 'private', title: 'Never sent to the AI provider' }) : null,
      (t.tags || []).map((tag) => el('span', { class: 'tag', text: tag })),
      t.notes.length ? el('span', { text: `${plural(t.notes.length, 'note')}` }) : null,
      el('span', { text: age(t.updated), title: `Updated ${shortTime(t.updated)}` })));

    return node;
  }

  move(taskId, to) {
    const t = this.app.tasks.find((x) => x.id === taskId);
    if (!t || t.status === to) return;
    this.app.stage(makeEvent('task.status', { taskId, from: t.status, to }));
  }

  /** Jump to a task and highlight it — used by summary bullets. */
  reveal(taskId) { this.flash = taskId; this.app.refresh(); }

  /* ---------- task detail ------------------------------------------------- */

  open(taskId) {
    const t = this.app.tasks.find((x) => x.id === taskId);
    if (!t) return;

    const title = el('input', { 'aria-label': 'Title', type: 'text', value: t.title, maxlength: '200' });
    const status = el('select', { 'aria-label': 'Status' }, STATUSES.map((s) => el('option', { value: s.id, selected: s.id === t.status, text: s.label })));
    const priority = el('select', { 'aria-label': 'Priority' }, PRIORITIES.map((p) => el('option', { value: p, selected: p === t.priority, text: p })));
    const tags = el('input', { 'aria-label': 'Tags', type: 'text', value: (t.tags || []).join(', '), placeholder: 'comma, separated' });
    const priv = el('input', { type: 'checkbox', checked: !!t.private });
    const note = el('textarea', { 'aria-label': 'Add a note', placeholder: 'What happened? This becomes a dated note in your changelog.' });

    const body = el('div', {},
      el('div', { class: 'field' }, el('label', { text: 'Title' }), title),
      el('div', { class: 'row' },
        el('div', { class: 'field' }, el('label', { text: 'Status' }), status),
        el('div', { class: 'field' }, el('label', { text: 'Priority' }), priority)),
      el('div', { class: 'field' }, el('label', { text: 'Tags' }), tags),
      el('div', { class: 'field' }, el('label', { class: 'check' }, priv,
        el('span', {}, el('strong', { text: 'Private' }), el('div', { class: 'hint', text: 'Never included in any request to the AI provider.' })))),
      el('div', { class: 'field' }, el('label', { text: 'Add a note' }), note),
      t.notes.length
        ? el('div', {}, el('div', { class: 'section-label', text: `History (${t.notes.length})` }),
          el('ul', { class: 'notes-list' }, [...t.notes].reverse().map((n) =>
            el('li', {}, el('time', { text: shortTime(n.ts) }), el('div', { text: n.text })))))
        : null,
      el('p', { class: 'sub', style: 'margin-top:14px' }, `${t.id} · created ${shortTime(t.created)}`),
    );

    const { close } = dialog({
      title: 'Task',
      body,
      buttons: [
        {
          label: 'Delete',
          class: 'danger',
          onClick: async () => {
            const yes = await confirm({
              title: 'Remove this task?',
              body: 'It stops showing on the board. The history stays in your log, so the changelog still records that it existed.',
              confirmLabel: 'Remove',
              danger: true,
            });
            if (!yes) return undefined;          // keep the dialog open
            if (this.app.stage(makeEvent('task.delete', { taskId })) === false) return undefined;
            return 'deleted';
          },
        },
        'spacer',
        { label: 'Cancel', value: false },
        {
          label: 'Save',
          class: 'primary',
          onClick: () => {
            const events = [];
            const fields = {};
            const newTitle = title.value.trim();
            if (newTitle && newTitle !== t.title) fields.title = newTitle;
            if (priority.value !== t.priority) fields.priority = priority.value;
            if (priv.checked !== !!t.private) fields.private = priv.checked;
            const newTags = tags.value.split(',').map((s) => s.trim()).filter(Boolean);
            if (JSON.stringify(newTags) !== JSON.stringify(t.tags || [])) fields.tags = newTags;

            if (Object.keys(fields).length) events.push(makeEvent('task.edit', { taskId, fields }));
            if (status.value !== t.status) events.push(makeEvent('task.status', { taskId, from: t.status, to: status.value }));
            if (note.value.trim()) events.push(makeEvent('task.note', { taskId, text: note.value.trim() }));

            if (events.length && this.app.stage(...events) === false) return undefined;
            return 'saved';
          },
        },
      ],
    });
    (t.notes.length ? note : title).focus();
    return close;
  }
}

/* ---------- new task ------------------------------------------------------ */

/** Quick-add. Kept separate from the detail dialog: creating wants one field, not eight. */
export function newTaskDialog(app) {
  const title = el('input', { 'aria-label': 'Title', type: 'text', placeholder: 'What needs doing?', maxlength: '200' });
  const status = el('select', { 'aria-label': 'Status' }, STATUSES.map((s) => el('option', { value: s.id, selected: s.id === 'todo', text: s.label })));
  const priority = el('select', { 'aria-label': 'Priority' }, PRIORITIES.map((p) => el('option', { value: p, selected: p === 'normal', text: p })));
  const tags = el('input', { 'aria-label': 'Tags', type: 'text', placeholder: 'comma, separated' });

  const submit = () => {
    const text = title.value.trim();
    if (!text) return undefined;
    const accepted = app.stage(makeEvent('task.create', {
      taskId: newTaskId(),
      title: text,
      status: status.value,
      priority: priority.value,
      tags: tags.value.split(',').map((s) => s.trim()).filter(Boolean),
    }));
    return accepted === false ? undefined : true;
  };

  title.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); if (submit()) closer(); } });

  const { close: closer } = dialog({
    title: 'New task',
    body: el('div', {},
      el('div', { class: 'field' }, el('label', { text: 'Title' }), title),
      el('div', { class: 'row' },
        el('div', { class: 'field' }, el('label', { text: 'Status' }), status),
        el('div', { class: 'field' }, el('label', { text: 'Priority' }), priority)),
      el('div', { class: 'field' }, el('label', { text: 'Tags' }), tags)),
    buttons: [{ label: 'Cancel', value: false }, { label: 'Add', class: 'primary', onClick: submit }],
  });
  title.focus();
}
