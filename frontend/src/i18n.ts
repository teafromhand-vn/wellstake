export type Lang = "en" | "vi";

type Dict = Record<string, { en: string; vi: string }>;

export const t: Dict = {
  appTitle: { en: "Wellstake V1 - Beta", vi: "Wellstake V1 - Beta" },
  appSubtitle: {
    en: "Mint & redeem preview on Arc Testnet",
    vi: "Bản xem trước mint & redeem trên Arc Testnet",
  },
  connect: { en: "Connect Wallet", vi: "Kết nối ví" },
  disconnect: { en: "Disconnect", vi: "Ngắt kết nối" },
  wrongNetwork: { en: "Wrong network", vi: "Sai mạng" },
  switchNetwork: { en: "Switch to Arc Testnet", vi: "Chuyển sang Arc Testnet" },
  addNetwork: { en: "Add Arc Testnet", vi: "Thêm Arc Testnet" },
  account: { en: "Account", vi: "Tài khoản" },

  overview: { en: "Overview", vi: "Tổng quan" },
  nav: { en: "Fund NAV", vi: "NAV quỹ" },
  rate: { en: "Rate (USD per share)", vi: "Tỷ giá (USD / share)" },
  totalSupply: { en: "Share supply", vi: "Cung share" },
  usdcBalance: { en: "USDC balance", vi: "Số dư USDC" },
  wskBalance: { en: "tWSK balance", vi: "Số dư tWSK" },
  woundDown: { en: "Wound down", vi: "Đã đóng quỹ" },

  mint: { en: "Mint", vi: "Mint" },
  redeem: { en: "Redeem", vi: "Redeem" },
  amount: { en: "Amount", vi: "Số lượng" },
  balance: { en: "Balance", vi: "Số dư" },
  max: { en: "Max", vi: "Tối đa" },
  mintDesc: {
    en: "Deposit USDC to receive tWSK shares after claim.",
    vi: "Nạp USDC để nhận share tWSK sau khi claim.",
  },
  redeemDesc: {
    en: "Burn tWSK to receive USDC. A 0.5% fee applies.",
    vi: "Đốt tWSK để nhận USDC. Phí 0.5%.",
  },
  requestMint: { en: "Request mint", vi: "Yêu cầu mint" },
  requestRedeem: { en: "Request redeem", vi: "Yêu cầu redeem" },
  approveFirst: { en: "Approve first", vi: "Cần approve trước" },
  approving: { en: "Approving...", vi: "Đang approve..." },
  requesting: { en: "Requesting...", vi: "Đang gửi yêu cầu..." },
  stepApproveUsdc: { en: "Approve USDC", vi: "Approve USDC" },
  stepRequest: { en: "Create request", vi: "Tạo yêu cầu" },
  stepClaim: { en: "Claim", vi: "Claim" },

  myRequests: { en: "My requests", vi: "Yêu cầu của tôi" },
  allRequests: { en: "All requests", vi: "Tất cả yêu cầu" },
  noRequests: { en: "No requests yet.", vi: "Chưa có yêu cầu nào." },
  id: { en: "ID", vi: "ID" },
  type: { en: "Type", vi: "Loại" },
  owner: { en: "Owner", vi: "Chủ sở hữu" },
  status: { en: "Status", vi: "Trạng thái" },
  action: { en: "Action", vi: "Hành động" },
  claim: { en: "Claim", vi: "Claim" },
  claimMany: { en: "Claim selected", vi: "Claim các mục đã chọn" },
  pending: { en: "Pending", vi: "Chờ" },
  claimed: { en: "Claimed", vi: "Đã claim" },
  filterMine: { en: "Mine only", vi: "Chỉ của tôi" },
  loading: { en: "Loading...", vi: "Đang tải..." },

  admin: { en: "Admin (manager)", vi: "Admin (manager)" },
  adminNote: {
    en: "Visible only for the manager account.",
    vi: "Chỉ hiển thị cho tài khoản manager.",
  },
  setNav: { en: "Set NAV", vi: "Đặt NAV" },
  newNav: { en: "New NAV (USDC, total fund value)", vi: "NAV mới (USDC, tổng giá trị quỹ)" },
  update: { en: "Update", vi: "Cập nhật" },
  notManager: { en: "Your account is not the manager.", vi: "Tài khoản của bạn không phải manager." },
  vaultLinked: { en: "Investment vault linked", vi: "Đã liên kết vault đầu tư" },

  txSubmitted: { en: "Transaction submitted:", vi: "Đã gửi giao dịch:" },
  txSuccess: { en: "Confirmed", vi: "Đã xác nhận" },
  error: { en: "Error", vi: "Lỗi" },
  close: { en: "Close", vi: "Đóng" },
  beta: {
    en: "Beta build on Arc Testnet. Funds are test-only.",
    vi: "Bản beta trên Arc Testnet. Tài sản chỉ để test.",
  },
};
