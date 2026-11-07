import Base

type Status is Data:
  SBacklog{}
  STodo{}
  SProgress{}
  SBlocked{}
  SReview{}
  SDone{}

type Priority is Data:
  PLow{}
  PNormal{}
  PHigh{}
  PUrgent{}

type Patch is Data:
  Patch{title: Maybe<&2, String>, status: Maybe<&2, Status>, priority: Maybe<&2, Priority>, tags: Maybe<&2, List<&2, String>>, private: Maybe<&2, Bool>}

type Payload is Data:
  Created{taskId: String, title: String, status: Status, priority: Priority, tags: List<&2, String>, private: Bool}
  StatusChanged{taskId: String, status: Status}
  Noted{taskId: String, text: String}
  Edited{taskId: String, patch: Patch}
  Deleted{taskId: String}
  SummarySet{date: String, kind: String, body: String}
  StandupSet{date: String, kind: String, text: String}
  Opaque{kind: String}

type DomainEvent is Data:
  Ev{id: String, ts: String, day: String, payload: Payload, canonical: String}

type Note is Data:
  Note{id: String, ts: String, text: String}

type Task is Data:
  Task{id: String, title: String, status: Status, priority: Priority, tags: List<&2, String>, private: Bool, deleted: Bool, created: String, updated: String, completed: Maybe<&2, String>, notes: List<&2, Note>}

type Recorded is Data:
  Recorded{id: String, ts: String, date: String, kind: String, body: String}

type Diagnostic is Data:
  MissingTask{eventId: String, taskId: String}
  DuplicateCreate{eventId: String, taskId: String}
  AfterDelete{eventId: String, taskId: String}
  Unsupported{eventId: String, kind: String}

type State is Data:
  State{tasks: List<&2, Task>, summaries: List<&2, Recorded>, reports: List<&2, Recorded>, diagnostics: List<&2, Diagnostic>, complete: Bool}

type MergeResult is Data:
  Merged{events: List<&2, DomainEvent>}
  EventConflict{id: String}

type ReplayResult is Data:
  Replayed{state: State}
  ReplayConflict{id: String}

type StageResult is Data:
  StageAccepted{event: DomainEvent}
  StageRejected{reason: String}

# An AI projection has no field for old summaries, reports, or opaque history.
# User-authored free text is a separate disclosed input owned by the coordinator.
type ContextTask is Data:
  ContextTask{id: String, title: String, status: Status, priority: Priority, tags: List<&2, String>, notes: List<&2, Note>}

type ContextEvent is Data:
  ContextEvent{id: String, ts: String, day: String, taskId: String, kind: String, title: String, status: Maybe<&2, Status>, text: String}
