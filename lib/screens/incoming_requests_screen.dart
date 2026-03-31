import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/service/states/states.dart';

class IncomingRequestsScreen extends StatelessWidget {
  const IncomingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CompanionsCubit, CompanionsState>(
      builder: (context, state) {
        final cubit = context.read<CompanionsCubit>();
        final requests = state.incomingRequests ?? [];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Companion Requests'),
          ),
          body: requests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'No incoming requests',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: requests.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey[200]),
                  itemBuilder: (context, i) {
                    final req = requests[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AppColors.primaryColor.withValues(alpha: 0.15),
                            child: Text(
                              req.fromUsername[0].toUpperCase(),
                              style: const TextStyle(
                                  color: AppColors.primaryColor,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '@${req.fromUsername}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ),
                          TextButton(
                            onPressed: state.actingRequestId != null
                                ? null
                                : () => cubit.rejectRequest(req.id),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[600]),
                            child: const Text('Decline'),
                          ),
                          const SizedBox(width: 4),
                          FilledButton(
                            onPressed: state.actingRequestId != null
                                ? null
                                : () => cubit.acceptRequest(req.id),
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryColor),
                            child: state.actingRequestId == req.id
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Text('Accept'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
