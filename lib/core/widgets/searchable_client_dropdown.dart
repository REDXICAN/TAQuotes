import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

class SearchableClientDropdown extends ConsumerStatefulWidget {
  final List<Client> clients;
  final Client? selectedClient;
  final Function(Client?) onClientSelected;
  final String hintText;
  final bool showAddButton;
  final VoidCallback? onAddClient;

  const SearchableClientDropdown({
    super.key,
    required this.clients,
    required this.selectedClient,
    required this.onClientSelected,
    this.hintText = 'Search or select a client...',
    this.showAddButton = true,
    this.onAddClient,
  });

  @override
  ConsumerState<SearchableClientDropdown> createState() => _SearchableClientDropdownState();
}

class _SearchableClientDropdownState extends ConsumerState<SearchableClientDropdown> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Client> _filteredClients = [];
  bool _isDropdownOpen = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _filteredClients = widget.clients;
    _searchController.text = widget.selectedClient?.company ?? '';
    
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _openDropdown();
      } else {
        // Delay closing to allow for item selection
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!_focusNode.hasFocus) {
            _closeDropdown();
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(SearchableClientDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    _filteredClients = widget.clients;
    if (widget.selectedClient != oldWidget.selectedClient) {
      _searchController.text = widget.selectedClient?.company ?? '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _closeDropdown();
    super.dispose();
  }

  void _filterClients(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredClients = widget.clients;
      } else {
        _filteredClients = widget.clients.where((client) {
          final searchLower = query.toLowerCase();
          return client.company.toLowerCase().contains(searchLower) ||
                 client.contactName.toLowerCase().contains(searchLower) ||
                 client.email.toLowerCase().contains(searchLower) ||
                 client.phone.toLowerCase().contains(searchLower);
        }).toList();
      }
    });
    
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _openDropdown() {
    if (_isDropdownOpen) return;

    _overlayEntry = _createOverlayEntry();
    final overlay = Overlay.of(context);
    overlay.insert(_overlayEntry!);
    setState(() {
      _isDropdownOpen = true;
    });
    }

  void _closeDropdown() {
    if (!_isDropdownOpen) return;
    
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isDropdownOpen = false;
    });
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    
    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 5.0),
          child: Material(
            elevation: 8.0,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showAddButton && widget.onAddClient != null)
                    InkWell(
                      onTap: () {
                        _closeDropdown();
                        widget.onAddClient!();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Add New Client',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Flexible(
                    child: _filteredClients.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No clients found',
                              style: TextStyle(
                                color: Theme.of(context).disabledColor,
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _filteredClients.length,
                            itemBuilder: (context, index) {
                              final client = _filteredClients[index];
                              final isSelected = widget.selectedClient?.id == client.id;
                              
                              return InkWell(
                                onTap: () {
                                  widget.onClientSelected(client);
                                  _searchController.text = client.company;
                                  _closeDropdown();
                                  _focusNode.unfocus();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  color: isSelected
                                      ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                                      : null,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.business,
                                        size: 20,
                                        color: isSelected
                                            ? Theme.of(context).primaryColor
                                            : Theme.of(context).disabledColor,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              client.company,
                                              style: TextStyle(
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: isSelected
                                                    ? Theme.of(context).primaryColor
                                                    : null,
                                              ),
                                            ),
                                            if (client.contactName.isNotEmpty)
                                              Text(
                                                client.contactName,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context).disabledColor,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Theme kept for potential future custom styling
    // ignore: unused_local_variable
    final theme = Theme.of(context);

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _searchController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    widget.onClientSelected(null);
                    _filterClients('');
                  },
                ),
              IconButton(
                icon: Icon(
                  _isDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                ),
                onPressed: () {
                  if (_isDropdownOpen) {
                    _focusNode.unfocus();
                  } else {
                    _focusNode.requestFocus();
                  }
                },
              ),
            ],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onChanged: (value) {
          _filterClients(value);
          // Clear selection if text doesn't match
          if (widget.selectedClient != null && 
              widget.selectedClient!.company != value) {
            widget.onClientSelected(null);
          }
        },
        onTap: () {
          if (!_isDropdownOpen) {
            _openDropdown();
          }
        },
      ),
    );
  }
}