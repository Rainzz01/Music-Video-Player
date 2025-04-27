import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/settings_page.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          //logo
          DrawerHeader(
            child: Center(
              child: Icon(
                Icons.music_note,
                size: 40,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
          ),

          //home title
          Padding(
            padding: const EdgeInsets.only(left: 25.0, top: 25),
            child: ListTile(
              title: const Text("H O M E"),
              leading: const Icon(Icons.home),
              onTap: () => Navigator.pop(context),
            ),
          ),

          //setting title
          Padding(
            padding: const EdgeInsets.only(left: 25.0, top: 0),
            child: ListTile(
              title: const Text("S E T T I N G S"),
              leading: const Icon(Icons.settings),
              onTap: () {
                //pop Drawer
                Navigator.pop(context);

                //navigate to settings page
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPage()),
                );
              },
            ),
          ),

          //import title
          //setting title
          Padding(
            padding: const EdgeInsets.only(left: 25.0, top: 0),
            child: ListTile(
              title: const Text("I M P O R T"),
              leading: const Icon(Icons.folder),
              onTap: () {
                //pop Drawer
                Navigator.pop(context);

                //navigate to settings page
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPage()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
