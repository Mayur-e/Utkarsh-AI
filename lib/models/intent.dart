enum IntentClass {
  stressHelp,
  taskAdd,
  planning,
  knowledgeQuery,
  casual,
  taskUpdate,
}

extension IntentExtension on IntentClass {
  String get label {
    switch (this) {
      case IntentClass.stressHelp:     return 'Stress Support';
      case IntentClass.taskAdd:       return 'Add Task';
      case IntentClass.taskUpdate:    return 'Update Task';
      case IntentClass.planning:       return 'Planning';
      case IntentClass.knowledgeQuery: return 'Query';
      case IntentClass.casual:          return 'Casual';
    }
  }
}
