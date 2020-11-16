import 'package:at_persistence_secondary_server/at_persistence_secondary_server.dart';

/// Builder class to build [AtMetaData] object.
class AtMetadataBuilder {
  var atMetaData;
  var currentUtcTime = DateTime.now().toUtc();
  var atSign = HivePersistenceManager.getInstance().atsign;

  /// AtMetadata Object : Optional parameter, If atMetadata object is null a new AtMetadata object is created.
  /// ttl : Time to live of the key. If ttl is null, atMetadata's ttl is assigned to ttl.
  /// ttb : Time to birth of the key. If ttb is null, atMetadata's ttb is assigned to ttb.
  /// ttr : Time to refresh of the key. If ttr is null, atMetadata's ttr is assigned to ttr.
  /// ccd : Cascade delete. If ccd is null, atMetadata's ccd is assigned to ccd.
  AtMetadataBuilder(
      {AtMetaData newAtMetaData,
      AtMetaData existingMetaData,
      int ttl,
      int ttb,
      int ttr,
      bool ccd,
      bool isBinary,
      bool isEncrypted}) {
    newAtMetaData ??= AtMetaData();
    atMetaData = newAtMetaData;
    atMetaData.createdAt ??= currentUtcTime;
    atMetaData.createdBy ??= atSign;
    atMetaData.updatedBy = atSign;
    atMetaData.updatedAt = currentUtcTime;
    atMetaData.status = 'active';

    //If new metadata is available, consider new metadata, else if existing metadata is available consider it.
    ttl ??= newAtMetaData.ttl;
    if (ttl == null && existingMetaData != null) ttl = existingMetaData.ttl;

    ttb ??= newAtMetaData.ttb;
    if (ttb == null && existingMetaData != null) ttb = existingMetaData.ttb;

    ttr ??= newAtMetaData.ttr;
    if (ttr == null && existingMetaData != null) ttr = existingMetaData.ttr;

    ccd ??= newAtMetaData.isCascade;
    if (ccd == null && existingMetaData != null) {
      ccd = existingMetaData.isCascade;
    }
    isBinary ??= newAtMetaData.isBinary;
    isEncrypted ??= newAtMetaData.isEncrypted;

    if (ttl != null) {
      setTTL(ttl, ttb: ttb);
    }
    if (ttb != null) {
      setTTB(ttb);
    }
    if (ttr != null) {
      setTTR(ttr);
    }
    if (ccd != null) {
      setCCD(ccd);
    }
    if (isBinary != null) {
      setIsBinary(isBinary);
    }
    if (isEncrypted != null) {
      setIsEncrypted(isEncrypted);
    }
  }

  void setTTL(int ttl, {int ttb}) {
    if (ttl != null) {
      atMetaData.ttl = ttl;
      atMetaData.expiresAt =
          _getExpiresAt(currentUtcTime.millisecondsSinceEpoch, ttl, ttb: ttb);
    }
  }

  void setTTB(int ttb) {
    if (ttb != null) {
      atMetaData.ttb = ttb;
      atMetaData.availableAt =
          _getAvailableAt(currentUtcTime.millisecondsSinceEpoch, ttb);
    }
  }

  void setTTR(int ttr) {
    if (ttr != null) {
      atMetaData.ttr = ttr;
      atMetaData.refreshAt = _getRefreshAt(currentUtcTime, ttr);
    }
  }

  void setCCD(bool ccd) {
    if (ccd != null) {
      atMetaData.isCascade = ccd;
    }
  }

  void setIsBinary(bool isBinary) {
    if (isBinary != null) {
      atMetaData.isBinary = isBinary;
    }
  }

  void setIsEncrypted(bool isEncrypted) {
    if (isEncrypted != null) {
      atMetaData.isEncrypted = isEncrypted;
    }
  }

  DateTime _getAvailableAt(int epochNow, int ttb) {
    if (ttb != null) {
      var availableAt = epochNow + ttb;
      return DateTime.fromMillisecondsSinceEpoch(availableAt).toUtc();
    }
    return null;
  }

  DateTime _getExpiresAt(int epochNow, int ttl, {int ttb}) {
    if (ttl != null) {
      var expiresAt = epochNow + ttl;
      if (ttb != null) {
        expiresAt = expiresAt + ttb;
      }
      return DateTime.fromMillisecondsSinceEpoch(expiresAt).toUtc();
    }
    return null;
  }

  DateTime _getRefreshAt(DateTime today, int ttr) {
    if (ttr == -1) {
      return null;
    }
    if (ttr != null) {
      return today.add(Duration(seconds: ttr));
    }
    return null;
  }

  AtMetaData build() {
    return atMetaData;
  }
}
