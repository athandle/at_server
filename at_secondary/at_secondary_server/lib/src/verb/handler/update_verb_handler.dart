import 'dart:collection';
import 'dart:convert';
import 'package:at_commons/at_commons.dart';
import 'package:at_secondary/src/server/at_secondary_config.dart';
import 'package:at_secondary/src/server/at_secondary_impl.dart';
import 'package:at_secondary/src/utils/notification_util.dart';
import 'package:at_secondary/src/verb/handler/abstract_verb_handler.dart';
import 'package:at_secondary/src/verb/verb_enum.dart';
import 'package:at_server_spec/at_verb_spec.dart';
import 'package:at_persistence_secondary_server/at_persistence_secondary_server.dart';
import 'package:at_server_spec/at_server_spec.dart';
import 'package:at_utils/at_utils.dart';
import 'package:at_secondary/src/utils/handler_util.dart';

// UpdateVerbHandler is used to process update verb
// update can be used to update the public/private keys
// Ex: update:public:email@alice alice@atsign.com \n
class UpdateVerbHandler extends AbstractVerbHandler {
  static final AUTO_NOTIFY = AtSecondaryConfig.autoNotify;
  static Update update = Update();

  UpdateVerbHandler(SecondaryKeyStore keyStore) : super(keyStore);

  // Method to verify whether command is accepted or not
  // Input: command
  @override
  bool accept(String command) =>
      command.startsWith(getName(VerbEnum.update) + ':') &&
      !command.startsWith('update:meta');

  // Method to return Instance of verb belongs to this VerbHandler
  @override
  Verb getVerb() {
    return update;
  }

  @override
  HashMap<String, String> parse(String command) {
    var verbParams = super.parse(command);
    if (command.contains('public:')) {
      verbParams.putIfAbsent('isPublic', () => 'true');
    }
    return verbParams;
  }

  // Method which will process update Verb
  // This will process given verb and write response to response object
  // Input : Response, verbParams, AtConnection
  @override
  Future<void> processVerb(
      Response response,
      HashMap<String, String> verbParams,
      InboundConnection atConnection) async {
    var updateParams = _getUpdateParams(verbParams);

    try {
      // Get the key and update the value
      var forAtSign = updateParams.sharedBy;
      var atSign = updateParams.sharedWith;
      var key = updateParams.atKey;
      var value = updateParams.value;
      var atData = AtData();
      atData.data = value;
      atData.metaData = AtMetaData();
      var ttl_ms = updateParams.metadata.ttl;
      var ttb_ms = updateParams.metadata.ttb;
      var ttr_ms = updateParams.metadata.ttr;
      var isBinary = updateParams.metadata.isBinary;
      var isEncrypted = updateParams.metadata.isEncrypted;
      var dataSignature = updateParams.metadata.dataSignature;
      var ccd = updateParams.metadata.ccd;
      // Get the key using verbParams (forAtSign, key, atSign)
      if (forAtSign != null) {
        forAtSign = AtUtils.formatAtSign(forAtSign);
        key = '${forAtSign}:${key}';
      }
      if (atSign != null) {
        atSign = AtUtils.formatAtSign(atSign);
        key = '${key}${atSign}';
      }
      // Append public: as prefix if key is public
      if (updateParams.metadata.isPublic != null &&
          updateParams.metadata.isPublic) {
        key = 'public:${key}';
      }
      var metadata = await keyStore.getMeta(key);
      var cacheRefreshMetaMap = validateCacheMetadata(metadata, ttr_ms, ccd);
      if (cacheRefreshMetaMap != null) {
        ttr_ms = cacheRefreshMetaMap[AT_TTR];
        ccd = cacheRefreshMetaMap[CCD];
      }

      //If ttr is set and atsign is not equal to currentAtSign, the key is
      //cached key.
      if (ttr_ms != null &&
          ttr_ms > 0 &&
          atSign != null &&
          atSign != AtSecondaryServerImpl.getInstance().currentAtSign) {
        key = 'cached:$key';
      }

      // update the key in data store
      var result = await keyStore.put(key, atData,
          time_to_live: ttl_ms,
          time_to_born: ttb_ms,
          time_to_refresh: ttr_ms,
          isCascade: ccd,
          isBinary: isBinary,
          isEncrypted: isEncrypted,
          dataSignature: dataSignature);
      response.data = result?.toString();
      _notify(atConnection, atSign, forAtSign, key, value, ttl_ms, ttr_ms,
          ttb_ms, ccd, metadata);
    } on InvalidSyntaxException {
      rethrow;
    } catch (exception) {
      response.isError = true;
      response.errorMessage = exception.toString();
      return;
    }
  }

  void _notify(atConnection, atSign, forAtSign, key, value, ttl_ms, ttr_ms,
      ttb_ms, isCascade, metadata) async {
    // store notification entry
    await NotificationUtil.storeNotification(atConnection, atSign, forAtSign,
        key, NotificationType.sent, OperationType.update,
        ttl_ms: ttl_ms);
    if (forAtSign == null) {
      return;
    }
    // send notification to other secondary if AUTO_NOTIFY is enabled
    atSign = AtUtils.formatAtSign(atSign);
    if (AUTO_NOTIFY && (atSign != forAtSign)) {
      forAtSign = AtUtils.formatAtSign(forAtSign);
      //if ttr is set, notify with value.
      if (ttr_ms == null && metadata != null) {
        ttr_ms = metadata.ttr;
        isCascade = metadata.isCascade;
      }
      if (ttr_ms != null) {
        key = '$AT_TTR:$ttr_ms:$CCD:$isCascade:$key:$value';
      }
      if (ttb_ms != null) {
        key = '$AT_TTB:$ttb_ms:$key';
      }
      if (ttl_ms != null) {
        key = '$AT_TTL:$ttl_ms:$key';
      }
      key = 'update:$key';
      try {
        await NotificationUtil.sendNotification(forAtSign, atConnection, key);
      } catch (exception) {
        logger.severe(
            'Exception while sending notification ${exception.toString()}');
      }
    }
  }

  UpdateParams _getUpdateParams(HashMap<String, String> verbParams) {
    if (verbParams['json'] != null) {
      print('update json');
      var jsonString = verbParams['json'];
      Map jsonMap = jsonDecode(jsonString);
      return UpdateParams.fromJson(jsonMap);
    }
    var updateParams = UpdateParams();
    updateParams.sharedBy = verbParams[FOR_AT_SIGN];
    updateParams.sharedWith = verbParams[AT_SIGN];
    updateParams.atKey = verbParams[AT_KEY];
    updateParams.value = verbParams[AT_VALUE];
    var metadata = Metadata();
    metadata.ttl = AtMetadataUtil.validateTTL(verbParams[AT_TTL]);
    metadata.ttb = AtMetadataUtil.validateTTB(verbParams[AT_TTB]);
    if (verbParams[AT_TTR] != null) {
      metadata.ttr = AtMetadataUtil.validateTTR(int.parse(verbParams[AT_TTR]));
    }
    metadata.ccd = AtMetadataUtil.getBoolVerbParams(verbParams[CCD]);
    metadata.dataSignature = verbParams[PUBLIC_DATA_SIGNATURE];
    metadata.isBinary = AtMetadataUtil.getBoolVerbParams(verbParams[IS_BINARY]);
    metadata.isEncrypted =
        AtMetadataUtil.getBoolVerbParams(verbParams[IS_ENCRYPTED]);
    metadata.isPublic = AtMetadataUtil.getBoolVerbParams(verbParams[IS_PUBLIC]);
    updateParams.metadata = metadata;
    return updateParams;
  }
}
