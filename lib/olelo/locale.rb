module Olelo
  # Simple localization implementation
  module Locale
    @locale = nil
    @translations = Hash.with_indifferent_access

    class << self
      attr_accessor :locale

      # Add locale hash
      #
      # A locale is a hash which maps
      # keys to strings.
      #
      # @param [Hash] Locale hash
      # @return [void]
      #
      def add(locale)
        @translations.update(locale[$1] || {}) if @locale =~ /\A(\w+)(_|-)/
        @translations.update(locale[@locale] || {})
        @translations.each_value(&:freeze)
      end

      # Return translated string for key
      #
      # A translated string can contain variables which are substituted in this method.
      # You have to pass an arguments hash.
      #
      # @option args [Integer] :count    if count is not 1, the key #{key}_plural is looked up instead
      # @option args [String]  :fallback Fallback string if key is not found in the locale
      # @param [Symbol, String] key which identifies string in locale
      # @param [Hash] args Arguments hash for string interpolation
      # @return [String] translated string
      #
      def translate(key, args = {})
        if @translations[key]
          @translations[key] % args
        else
          args[:fallback] || "##{key}"
        end
      end
    end
  end
end

class Symbol
  # Lookup translated string identified by this symbol
  #
  # @param [Hash] args Arguments hash for string interpolation
  # @return [String] translated string
  # @see Olelo::Locale#translate
  #
  def t(args = {})
    Olelo::Locale.translate(self, args)
  end
end
