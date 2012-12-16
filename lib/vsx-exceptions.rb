
class VsxError < StandardError; end

class NoResponse < VsxError;    end

class InvalidResponse < VsxError;    end

class NoConnection < VsxError; end

class DidNotComply < VsxError; end
