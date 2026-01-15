import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/directus_sdk/directus.dart';
import 'package:nocodb/features/directus/providers/directus_providers.dart';

class DirectusItemEditorPage extends HookConsumerWidget {
  const DirectusItemEditorPage({
    super.key,
    required this.collection,
    this.itemId,
  });

  final String collection;
  final String? itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldsAsync = ref.watch(collectionFieldsProvider(collection));
    final formData = useState<Map<String, dynamic>>({});
    final isLoading = useState(false);

    useEffect(() {
      if (itemId != null) {
        // Load existing item
        directus.getItem(collection, itemId!).then((item) {
          formData.value = Map<String, dynamic>.from(item);
        });
      }
      return null;
    }, [itemId]);

    Future<void> handleSave() async {
      isLoading.value = true;
      try {
        if (itemId == null) {
          // Create new item
          await ref
              .read(collectionItemsProvider(collection).notifier)
              .createItem(formData.value);
          if (context.mounted) {
            notifySuccess(context, message: 'Item created successfully');
            Navigator.pop(context);
          }
        } else {
          // Update existing item
          await ref
              .read(collectionItemsProvider(collection).notifier)
              .updateItem(itemId!, formData.value);
          if (context.mounted) {
            notifySuccess(context, message: 'Item updated successfully');
            Navigator.pop(context);
          }
        }
      } catch (e, s) {
        if (context.mounted) {
          notifyError(context, e, s);
        }
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(itemId == null ? 'New Item' : 'Edit Item'),
        actions: [
          IconButton(
            onPressed: isLoading.value ? null : handleSave,
            icon: isLoading.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
          ),
        ],
      ),
      body: fieldsAsync.when(
        data: (fields) {
          // Filter out system fields and primary key (for create)
          final editableFields = fields.where((field) {
            final isPrimaryKey = field.schema?['is_primary_key'] == true;
            final isSystemField = field.field.startsWith('date_') ||
                field.field.startsWith('user_');
            return !isPrimaryKey && !isSystemField;
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: editableFields.length + 1,
            itemBuilder: (context, index) {
              if (index == editableFields.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: ElevatedButton(
                    onPressed: isLoading.value ? null : handleSave,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(itemId == null ? 'Create' : 'Update'),
                  ),
                );
              }

              final field = editableFields[index];
              final fieldName = field.field;
              final fieldType = field.type;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildFieldInput(
                  fieldName: fieldName,
                  fieldType: fieldType,
                  initialValue: formData.value[fieldName],
                  onChanged: (value) {
                    formData.value = {
                      ...formData.value,
                      fieldName: value,
                    };
                  },
                  enabled: !isLoading.value,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading fields: $error'),
        ),
      ),
    );
  }

  Widget _buildFieldInput({
    required String fieldName,
    required String fieldType,
    required dynamic initialValue,
    required Function(dynamic) onChanged,
    required bool enabled,
  }) {
    final controller = TextEditingController(
      text: initialValue?.toString() ?? '',
    );

    // Determine input type based on field type
    TextInputType keyboardType = TextInputType.text;
    int? maxLines = 1;

    switch (fieldType.toLowerCase()) {
      case 'integer':
      case 'biginteger':
      case 'float':
      case 'decimal':
        keyboardType = TextInputType.number;
      case 'text':
        maxLines = 5;
      case 'boolean':
        return SwitchListTile(
          title: Text(_formatFieldName(fieldName)),
          value: initialValue == true || initialValue == 1,
          onChanged: enabled ? (value) => onChanged(value) : null,
        );
      case 'date':
        keyboardType = TextInputType.datetime;
      case 'time':
        keyboardType = TextInputType.datetime;
      case 'datetime':
      case 'timestamp':
        keyboardType = TextInputType.datetime;
    }

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: _formatFieldName(fieldName),
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      onChanged: (value) {
        // Convert to appropriate type
        dynamic convertedValue = value;
        if (fieldType.toLowerCase() == 'integer' ||
            fieldType.toLowerCase() == 'biginteger') {
          convertedValue = int.tryParse(value);
        } else if (fieldType.toLowerCase() == 'float' ||
            fieldType.toLowerCase() == 'decimal') {
          convertedValue = double.tryParse(value);
        }
        onChanged(convertedValue);
      },
    );
  }

  String _formatFieldName(String fieldName) {
    return fieldName
        .split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
