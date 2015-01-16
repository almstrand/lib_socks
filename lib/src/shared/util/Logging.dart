part of shared_socks;

/**
 * Utility methods to simplify logging.
 */
class Logging {

  /**
   * Replace newline characters with "/" to support producing a condensed log files containing no line breaks.
   * Optionally limit line length to avoid excessive logging.
   *
   * @param str
   *      String to process.
   * @return
   *      Optionally truncated string containing no line break characters.
   */
  static String stripNewLinesAndLimitLength(String str, {int maxChars: 256}) {
    String strippedString = str.replaceAll("\x0A", "/");
    strippedString = strippedString.replaceAll("\x0D", "/");
    if (strippedString.length > maxChars) {
      strippedString = strippedString.substring(0, maxChars) + "...";
    }
    return strippedString;
  }

}