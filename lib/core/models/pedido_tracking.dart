// lib/core/models/pedido_tracking.dart

/// Model for tracking "Pedidos" (Orders) from logistics Excel
/// Maps directly to the LOGÍSTICA - CONTROL DE PEDIDOS structure
class PedidoTracking {
  final String id; // Firebase key
  final String? fechaEntrada; // FECHA DE ENTRADA
  final String? numeroPedido; // # DE PEDIDO
  final String? oc; // OC
  final String? estatus; // ESTATUS
  final String? cliente; // CLIENTE
  final String? vendedor; // VENDEDOR
  final String? destino; // DESTINO
  final String? referencia; // REFERENCIA
  final String? proveedorOrigen; // PROVEEDOR/ ORIGEN
  final String? salesOrder; // SALES ORDER
  final String? transfer; // TRANSFER
  final String? salesInvoice; // SALES INVOICE
  final String? fechaFactura; // FECHA FACTURA
  final String? arriboAduana; // ARRIBO A ADUANA
  final String? numPedimento; // NUM. DE PEDIMENTO
  final String? remision; // REMISIÓN
  final String? fletera; // FLETERA
  final String? guia; // GUIA
  final String? documentado; // DOCUMENTADO
  final String? entregaCancun; // ENTREGA CANCÚN
  final String? entregaAproximada; // ENTREGA APROXIMADA
  final String? entregaReal; // ENTREGA REAL
  final DateTime? importedAt;
  final DateTime? lastUpdated;

  PedidoTracking({
    required this.id,
    this.fechaEntrada,
    this.numeroPedido,
    this.oc,
    this.estatus,
    this.cliente,
    this.vendedor,
    this.destino,
    this.referencia,
    this.proveedorOrigen,
    this.salesOrder,
    this.transfer,
    this.salesInvoice,
    this.fechaFactura,
    this.arriboAduana,
    this.numPedimento,
    this.remision,
    this.fletera,
    this.guia,
    this.documentado,
    this.entregaCancun,
    this.entregaAproximada,
    this.entregaReal,
    this.importedAt,
    this.lastUpdated,
  });

  factory PedidoTracking.fromJson(String id, Map<String, dynamic> json) {
    return PedidoTracking(
      id: id,
      fechaEntrada: json['fecha_entrada']?.toString(),
      numeroPedido: json['numero_pedido']?.toString(),
      oc: json['oc']?.toString(),
      estatus: json['estatus']?.toString(),
      cliente: json['cliente']?.toString(),
      vendedor: json['vendedor']?.toString(),
      destino: json['destino']?.toString(),
      referencia: json['referencia']?.toString(),
      proveedorOrigen: json['proveedor_origen']?.toString(),
      salesOrder: json['sales_order']?.toString(),
      transfer: json['transfer']?.toString(),
      salesInvoice: json['sales_invoice']?.toString(),
      fechaFactura: json['fecha_factura']?.toString(),
      arriboAduana: json['arribo_aduana']?.toString(),
      numPedimento: json['num_pedimento']?.toString(),
      remision: json['remision']?.toString(),
      fletera: json['fletera']?.toString(),
      guia: json['guia']?.toString(),
      documentado: json['documentado']?.toString(),
      entregaCancun: json['entrega_cancun']?.toString(),
      entregaAproximada: json['entrega_aproximada']?.toString(),
      entregaReal: json['entrega_real']?.toString(),
      importedAt: json['imported_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['imported_at'] as int)
          : null,
      lastUpdated: json['last_updated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['last_updated'] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fecha_entrada': fechaEntrada,
      'numero_pedido': numeroPedido,
      'oc': oc,
      'estatus': estatus,
      'cliente': cliente,
      'vendedor': vendedor,
      'destino': destino,
      'referencia': referencia,
      'proveedor_origen': proveedorOrigen,
      'sales_order': salesOrder,
      'transfer': transfer,
      'sales_invoice': salesInvoice,
      'fecha_factura': fechaFactura,
      'arribo_aduana': arriboAduana,
      'num_pedimento': numPedimento,
      'remision': remision,
      'fletera': fletera,
      'guia': guia,
      'documentado': documentado,
      'entrega_cancun': entregaCancun,
      'entrega_aproximada': entregaAproximada,
      'entrega_real': entregaReal,
      'imported_at': importedAt?.millisecondsSinceEpoch,
      'last_updated': lastUpdated?.millisecondsSinceEpoch,
    };
  }

  /// Get display name for tracking (Pedido # or OC)
  String get displayName => numeroPedido ?? oc ?? 'N/A';

  /// Get status color based on estatus field
  String get statusColor {
    final status = (estatus ?? '').toUpperCase();
    if (status.contains('ENVIADO')) return 'green';
    if (status.contains('ENTREGADO')) return 'blue';
    if (status.contains('ALMACÉN') || status.contains('ALMACEN')) return 'orange';
    if (status.contains('CANCELADO')) return 'red';
    if (status.contains('ENTREGAR')) return 'amber';
    return 'grey';
  }

  /// Check if has sales order
  bool get hasSalesOrder => salesOrder?.isNotEmpty == true && salesOrder != 'X';

  /// Check if has transfer
  bool get hasTransfer => transfer?.isNotEmpty == true && transfer != 'X';

  PedidoTracking copyWith({
    String? id,
    String? fechaEntrada,
    String? numeroPedido,
    String? oc,
    String? estatus,
    String? cliente,
    String? vendedor,
    String? destino,
    String? referencia,
    String? proveedorOrigen,
    String? salesOrder,
    String? transfer,
    String? salesInvoice,
    String? fechaFactura,
    String? arriboAduana,
    String? numPedimento,
    String? remision,
    String? fletera,
    String? guia,
    String? documentado,
    String? entregaCancun,
    String? entregaAproximada,
    String? entregaReal,
    DateTime? importedAt,
    DateTime? lastUpdated,
  }) {
    return PedidoTracking(
      id: id ?? this.id,
      fechaEntrada: fechaEntrada ?? this.fechaEntrada,
      numeroPedido: numeroPedido ?? this.numeroPedido,
      oc: oc ?? this.oc,
      estatus: estatus ?? this.estatus,
      cliente: cliente ?? this.cliente,
      vendedor: vendedor ?? this.vendedor,
      destino: destino ?? this.destino,
      referencia: referencia ?? this.referencia,
      proveedorOrigen: proveedorOrigen ?? this.proveedorOrigen,
      salesOrder: salesOrder ?? this.salesOrder,
      transfer: transfer ?? this.transfer,
      salesInvoice: salesInvoice ?? this.salesInvoice,
      fechaFactura: fechaFactura ?? this.fechaFactura,
      arriboAduana: arriboAduana ?? this.arriboAduana,
      numPedimento: numPedimento ?? this.numPedimento,
      remision: remision ?? this.remision,
      fletera: fletera ?? this.fletera,
      guia: guia ?? this.guia,
      documentado: documentado ?? this.documentado,
      entregaCancun: entregaCancun ?? this.entregaCancun,
      entregaAproximada: entregaAproximada ?? this.entregaAproximada,
      entregaReal: entregaReal ?? this.entregaReal,
      importedAt: importedAt ?? this.importedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
