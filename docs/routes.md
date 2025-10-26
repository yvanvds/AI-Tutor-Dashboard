# routes
/goals              — shows root goals; each row clickable to open its children
/goals/:id          — shows children of this goal; actions: add/edit/delete/reorder
/goals/:id/edit     — edit page for that specific goal
/goals/new?parentId=… — create form; parent prefilled if provided

# ideas
- a breadcrumb idea (Goals > Doc Title > Child title)
- navigation policy: back arrow = parent; home icon = root list; up/down arrow = previous/next doc on same level
