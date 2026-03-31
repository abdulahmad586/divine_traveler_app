class ApiResponse{
  bool? ok;
  dynamic data;
  String? message;

  ApiResponse({this.ok=false, this.message, this.data});

  factory ApiResponse.fromMap(Map<String,dynamic> jsonMap, {String dataField="data"}){
    return ApiResponse(
      ok: jsonMap['ok']??false,
      message: jsonMap['message'],
      data: jsonMap[dataField],
    );
  }

}