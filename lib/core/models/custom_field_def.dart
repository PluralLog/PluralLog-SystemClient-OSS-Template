/// Defines a custom field that can be tracked across all members.
/// Each Member stores its own values in member.customFields[fieldId].
class CustomFieldDef {
  final String id;
  String name;
  String fieldType; // 'text', 'markdown', 'boolean', 'choice', 'image_url'
  List<String>? choices; // For 'choice' type
  int sortOrder;

  CustomFieldDef({
    required this.id,
    required this.name,
    this.fieldType = 'text',
    this.choices,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'fieldType': fieldType,
        'choices': choices?.join('|||'),
        'sortOrder': sortOrder,
      };

  factory CustomFieldDef.fromMap(Map<String, dynamic> map) => CustomFieldDef(
        id: map['id'],
        name: map['name'],
        fieldType: map['fieldType'] ?? 'text',
        choices:
            map['choices'] != null && (map['choices'] as String).isNotEmpty
                ? (map['choices'] as String).split('|||')
                : null,
        sortOrder: map['sortOrder'] ?? 0,
      );
}
