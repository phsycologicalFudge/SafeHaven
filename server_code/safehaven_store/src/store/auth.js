export const getBearerToken = (request) => {
  const header = request.headers.get("authorization") || "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : "";
};

export const normalizeStoreUser = (user) => {
  if (!user || !user.id) return null;

  return {
    id: String(user.id),
    email: user.email ? String(user.email) : "",
    developerEnabled: user.developerEnabled === true || Number(user.developer_enabled || 0) === 1,
    admin: user.admin === true,
  };
};
