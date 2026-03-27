import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/app_providers.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/members/members_screen.dart';
import 'features/switching/switching_screen.dart';
import 'features/journal/journal_screen.dart';
import 'features/polls/polls_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/settings/settings_screen.dart';


/*
This is a container for the rest of your app content. The shell is a persistent widget whose content you change, 
so in the below example we maintain the bottomNavigationBar of the scaffold, but alter the body to switch to different screens. 

If you wanted a non tab based navigation, you would change this. 
*/
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);

    final screens = <AppTab, Widget>{
      AppTab.dashboard: const DashboardScreen(),
      AppTab.members: const MembersScreen(),
      AppTab.switching: const SwitchingScreen(),
      AppTab.journal: const JournalScreen(),
      AppTab.polls: const PollsScreen(),
      AppTab.chat: const ChatScreen(),
      AppTab.settings: const SettingsScreen(),
    };

    return Scaffold(
      body: screens[currentTab] ?? const DashboardScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: AppTab.values.indexOf(currentTab),
        onDestinationSelected: (i) {
          ref.read(currentTabProvider.notifier).state = AppTab.values[i];
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Alters'), // Members, I chose Alters due to length
          NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Switch'),
          NavigationDestination(icon: Icon(Icons.book), label: 'Journal'),
          NavigationDestination(icon: Icon(Icons.poll), label: 'Polls'),
          NavigationDestination(icon: Icon(Icons.chat), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
