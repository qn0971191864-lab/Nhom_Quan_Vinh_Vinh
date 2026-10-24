abstract class ProjectModel<T extends Object> {
  T get id;

  Object get object => this;

  Type get classType => object.runtimeType;

  void displayDetails();
}
