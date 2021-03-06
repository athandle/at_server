import 'package:at_secondary/src/connection/inbound/inbound_connection_metadata.dart';
import 'package:at_secondary/src/server/at_secondary_impl.dart';
import 'package:at_server_spec/at_server_spec.dart';
import 'package:at_secondary/src/verb/handler/response/response_handler.dart';
import 'package:at_server_spec/at_verb_spec.dart';
import 'package:at_utils/at_logger.dart';
import 'package:at_secondary/src/exception/global_exception_handler.dart';

abstract class BaseResponseHandler implements ResponseHandler {
  var logger;
  BaseResponseHandler() {
    logger = AtSignLogger(runtimeType.toString());
  }
  @override
  void process(AtConnection connection, Response response) async {
    logger.finer('Got response: ${response}');
    var result = response.data;
    try {
      if (response.isError || response.isStream) {
        if (response.isError) {
          logger.severe(response.errorMessage);
        }
        return;
      }
      InboundConnectionMetadata atConnectionMetadata = connection.getMetaData();
      var isAuthenticated = atConnectionMetadata.isAuthenticated;
      var atSign = AtSecondaryServerImpl.getInstance().currentAtSign;
      var isPolAuthenticated = connection.getMetaData().isPolAuthenticated;
      var fromAtSign = atConnectionMetadata.fromAtSign;
      var prompt = isAuthenticated
          ? '$atSign@'
          : (isPolAuthenticated ? '$fromAtSign@' : '@');
      var responseMessage = getResponseMessage(result, prompt);
      await connection.write(responseMessage);
    } on Exception catch (e) {
      logger.severe('exception in writing response to socket:${e.toString()}');
      GlobalExceptionHandler.getInstance().handle(e, atConnection: connection);
    }
  }

  /// Construct a response message from verb result and the prompt to return to the user
  /// @params - result of the processed [Verb]
  /// @params - prompt to return to the user. e.g. @ or @alice@
  /// @return - response message to write to requesting connection
  String getResponseMessage(String verbResult, String prompt);
}
