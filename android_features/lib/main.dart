import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: FlutterContactsExample());
  }
}

class ContactDetails extends StatefulWidget {
  const ContactDetails({super.key});

  @override
  _ContactDetailsState createState() => _ContactDetailsState();
}

class _ContactDetailsState extends State<ContactDetails> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  Uint8List? photoBytes;

  // Pick or take a photo
  Future<void> pickPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      final bytes = await File(pickedFile.path).readAsBytes();
      setState(() {
        photoBytes = bytes; // update preview
      });
    }
  }

  Future<void> createNewContact() async {
    // 1️⃣ Request permission
    final status = await FlutterContacts.permissions.request(PermissionType.readWrite);

    if (status == PermissionStatus.granted) {
      if (firstNameController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('First name and phone number are required!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return; // stop if empty
      }

      // 2️⃣ Build your Contact object
      final contact = Contact(
        name: Name(first: firstNameController.text, last: lastNameController.text),
        phones: [Phone(number: phoneController.text)],
        emails: [Email(address: emailController.text)],
        photo: photoBytes != null ? Photo(fullSize: photoBytes) : null
      );
    
      // 3️⃣ Save it to the phone
      String newContactId = await FlutterContacts.create(contact);

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact saved successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.pop(context); // go back after saving
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contacts permission denied!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Contact")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: pickPhoto,
              child: CircleAvatar(
                radius: 50,
                backgroundImage:
                    photoBytes != null ? MemoryImage(photoBytes!) : null,
                child:
                    photoBytes == null ? const Icon(Icons.camera_alt, size: 50) : null,
              ),
            ),
            TextField(
              controller: firstNameController,
              decoration: const InputDecoration(labelText: "First Name"),
            ),
            TextField(
              controller: lastNameController,
              decoration: const InputDecoration(labelText: "Last Name"),
            ),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Phone Number"),
            ),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: createNewContact,
              child: const Text("Save Contact"),
            ),
          ],
        ),
      )
    );
  }
}

class FlutterContactsExample extends StatefulWidget {
  const FlutterContactsExample({super.key});

  @override
  State<FlutterContactsExample> createState() => _FlutterContactsExampleState();
}

class _FlutterContactsExampleState extends State<FlutterContactsExample> {
  List<Contact>? _contacts;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  void initialize() {
    FlutterContacts.onDatabaseChange.listen((_) {
      _fetchContacts();
    });
    _fetchContacts();
  }

  Future _fetchContacts() async {
    var status = await FlutterContacts.permissions.request(
      PermissionType.readWrite,
    );
    if (status == PermissionStatus.denied) {
      setState(() => _permissionDenied = true);
    } else {
      var contacts = await FlutterContacts.getAll(
        properties: ContactProperties.all,
      );
      setState(() => _contacts = contacts);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Own Contacts App')),
      body: _body(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ContactDetails()),
            );
        },
        child: const Icon(Icons.add),
    ),
    );
  }

  Widget _body() {
    if (_permissionDenied) {
      return const Center(child: Text('Permission denied'));
    }
    if (_contacts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: _contacts!.length,
      itemBuilder: (context, i) => ListTile(
        title: Text(_contacts![i].displayName ?? "..."),
        onTap: () {
          FlutterContacts.get(
            _contacts![i].id!,
            properties: ContactProperties.all,
          ).then((contact) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ContactPage(contact!)),
            );
          });
        },
      ),
    );
  }
}

class ContactPage extends StatelessWidget {
  final Contact contact;
  const ContactPage(this.contact, {super.key});

  // Delete contact safely with permission check
  Future<void> deleteContact(BuildContext context, Contact contact) async {
    final status = await FlutterContacts.permissions.request(PermissionType.readWrite);

    if (status == PermissionStatus.granted) {
      final id = contact.id;
      if (id != null) {
        try {
          await FlutterContacts.delete(id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contact deleted successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context); // go back after deleting
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete contact: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Contact ID is null'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission denied!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(contact.displayName ?? "...")),
    body: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
          child: CircleAvatar(
            radius: 50,
            backgroundImage: (contact.photo?.fullSize ?? contact.photo?.thumbnail) != null
                ? MemoryImage(contact.photo?.fullSize ?? contact.photo!.thumbnail!)
                : null,
            child: (contact.photo?.fullSize == null && contact.photo?.thumbnail == null)
                ? Text(
                    contact.displayName?.isNotEmpty == true
                        ? contact.displayName![0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 40),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('First name: ${contact.name?.first}'),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Last name: ${contact.name?.last}'),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Phone number: ${contact.phones.isNotEmpty ? contact.phones.first.number : '(none)'}',
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Email address: ${contact.emails.isNotEmpty ? contact.emails.first.address : '(none)'}',
            ),
          ),
          const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => deleteContact(context, contact),
              child: const Text("Delete Contact"),
            ),
        ],
      ),
    ),
    
  );
}
