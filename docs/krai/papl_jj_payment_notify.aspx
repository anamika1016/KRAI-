<%@ Page Language="C#" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Net" %>
<%@ Import Namespace="System.Net.Mail" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="System.Text.RegularExpressions" %>
<%--
  papl_jj_payment_notify.aspx - Ploughman Agro (KRAI app) ki Jeevika Jankar
  Payment Notification mail, notification@ploughmanagro.com se.

  krai team ke liye:
  1. Is file ko krai ki website root me rakhein (jahan jj_payment_notify.aspx hai).
     Ye ek alag page hai; ASA ka jj_payment_notify.aspx bilkul nahi badalta.
  2. web.config ke <appSettings> me ye keys jodein:
       <add key="PAPL_SMTP_HOST"     value="smtp.gmail.com" />
       <add key="PAPL_SMTP_PORT"     value="587" />
       <add key="PAPL_SMTP_USER"     value="notification@ploughmanagro.com" />
       <add key="PAPL_SMTP_PASSWORD" value="(Google App Password)" />
     ploughmanagro.com ki mail Google Workspace par hai, isliye password
     Google account ka "App Password" hoga (2-Step Verification on karke).
  3. Code-behind ki zarurat nahi; page khud mail bhejta hai.

  App ise GET se bulata hai:
    papl_jj_payment_notify.aspx?to_email=..&to_name=..&subject=..&jj_id=..&name=..
      &mobile_no=..&financial_year=..&bill_month=..&bill_id=..&approval_date=..
      &amount=..&transaction_id=..&transaction_type=..&transaction_date=..
      &updated_on=..&updated_by=..
  message, test_mode, actual_email bhi aate hain; inhe ignore kiya jata hai.

  Jawab JSON me: {"success":true,...} ya {"success":false,"message":"..."}.
--%>
<script runat="server">
    private const string FromAddress = "notification@ploughmanagro.com";
    private const string FromName = "Ploughman Agro";

    protected void Page_Load(object sender, EventArgs e)
    {
        Response.Clear();
        Response.ContentType = "application/json";
        Response.ContentEncoding = Encoding.UTF8;

        string to = (Request.QueryString["to_email"] ?? "").Trim();
        if (to.Length == 0 || !Regex.IsMatch(to, @"^[^@\s]+@[^@\s]+\.[^@\s]+$"))
        {
            Respond(false, "to_email missing or invalid");
            return;
        }

        string subject = (Request.QueryString["subject"] ?? "").Trim();
        if (subject.Length == 0) subject = "Jeevika Jankar Payment Notification";

        try
        {
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;

            using (MailMessage mail = new MailMessage())
            {
                mail.From = new MailAddress(Setting("PAPL_SMTP_USER", FromAddress), FromName, Encoding.UTF8);
                mail.To.Add(new MailAddress(to, (Request.QueryString["to_name"] ?? "").Trim(), Encoding.UTF8));
                mail.Subject = subject;
                mail.SubjectEncoding = Encoding.UTF8;
                mail.Body = BuildHtml();
                mail.BodyEncoding = Encoding.UTF8;
                mail.IsBodyHtml = true;

                using (SmtpClient smtp = new SmtpClient(Setting("PAPL_SMTP_HOST", "smtp.gmail.com"),
                                                        int.Parse(Setting("PAPL_SMTP_PORT", "587"))))
                {
                    smtp.EnableSsl = true;
                    smtp.UseDefaultCredentials = false;
                    smtp.Credentials = new NetworkCredential(Setting("PAPL_SMTP_USER", FromAddress),
                                                             Setting("PAPL_SMTP_PASSWORD", ""));
                    smtp.Timeout = 15000;
                    smtp.Send(mail);
                }
            }
            Respond(true, "Mail sent successfully to " + to);
        }
        catch (Exception ex)
        {
            Respond(false, "Mail not sent: " + ex.Message);
        }
    }

    private static string Setting(string key, string fallback)
    {
        string value = ConfigurationManager.AppSettings[key];
        return string.IsNullOrWhiteSpace(value) ? fallback : value.Trim();
    }

    private void Respond(bool success, string message)
    {
        Response.StatusCode = 200;
        Response.Write("{\"success\":" + (success ? "true" : "false") +
                       ",\"status\":\"" + (success ? "sent" : "failed") +
                       "\",\"message\":" + JsonString(message) + "}");
    }

    // Page ka apna markup nahi bhejna; sirf upar likha JSON jaye.
    protected override void Render(HtmlTextWriter writer) { }

    private static string JsonString(string value)
    {
        StringBuilder sb = new StringBuilder("\"");
        foreach (char c in value ?? "")
        {
            if (c == '"' || c == '\\') sb.Append('\\').Append(c);
            else if (c < ' ') sb.AppendFormat("\\u{0:x4}", (int)c);
            else sb.Append(c);
        }
        return sb.Append('"').ToString();
    }

    // {{field}} ki jagah query ki value (HtmlEncode ke saath); khali ho to "-".
    private string BuildHtml()
    {
        return Regex.Replace(Template, @"\{\{(\w+)\}\}", match =>
        {
            string value = Request.QueryString[match.Groups[1].Value];
            return HttpUtility.HtmlEncode(string.IsNullOrWhiteSpace(value) ? "-" : value.Trim());
        });
    }

    private const string Template = @"<!DOCTYPE html>
<html lang=""hi"">
  <head>
    <meta charset=""utf-8"">
    <meta name=""viewport"" content=""width=device-width, initial-scale=1"">
    <title>Jeevika Jankar Payment Notification</title>
  </head>
  <body style=""margin:0;padding:0;background:#eef3ef;font-family:Arial,Helvetica,sans-serif;color:#1f2d26;"">
    <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" border=""0"" style=""background:#eef3ef;"">
      <tr>
        <td align=""center"" style=""padding:28px 12px;"">
          <table role=""presentation"" width=""600"" cellpadding=""0"" cellspacing=""0"" border=""0"" style=""width:100%;max-width:600px;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid #d8e4dc;"">
            <tr>
              <td style=""background:#1f6b3a;padding:26px 28px;"">
                <div style=""color:#cfe8d6;font-size:12px;letter-spacing:1.5px;font-weight:bold;text-transform:uppercase;"">Ploughman Agro Pvt. Ltd.</div>
                <div style=""color:#ffffff;font-size:22px;font-weight:bold;padding-top:6px;line-height:1.3;"">Jeevika Jankar Payment Notification</div>
              </td>
            </tr>
            <tr>
              <td style=""padding:26px 28px 8px;font-size:15px;line-height:1.6;"">Namaste <strong>{{name}}</strong>,</td>
            </tr>
            <tr>
              <td style=""padding:12px 28px 6px;"">
                <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" border=""0"" style=""background:#e9f6ee;border:1px solid #bfe3cb;border-radius:10px;"">
                  <tr>
                    <td style=""padding:18px 20px;"">
                      <div style=""font-size:12px;color:#4d6b58;text-transform:uppercase;letter-spacing:1px;font-weight:bold;"">Payment Amount</div>
                      <div style=""font-size:30px;color:#16733b;font-weight:bold;padding-top:4px;"">&#8377; {{amount}}</div>
                    </td>
                    <td align=""right"" style=""padding:18px 20px;"">
                      <span style=""display:inline-block;background:#16733b;color:#ffffff;font-size:12px;font-weight:bold;padding:6px 14px;border-radius:20px;"">PAID</span>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr>
              <td style=""padding:18px 28px 6px;"">
                <div style=""font-size:14px;font-weight:bold;color:#1f6b3a;padding-bottom:8px;"">Payment Details</div>
                <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" border=""0"" style=""border:1px solid #dfe8e2;border-radius:8px;border-collapse:separate;font-size:14px;"">
                  <tr style=""background:#f6faf7;""><td style=""padding:11px 14px;color:#5b6b63;width:45%;border-bottom:1px solid #e6ede9;"">Transaction ID / UTR</td><td style=""padding:11px 14px;font-weight:bold;border-bottom:1px solid #e6ede9;"">{{transaction_id}}</td></tr>
                  <tr><td style=""padding:11px 14px;color:#5b6b63;border-bottom:1px solid #e6ede9;"">Transaction Type</td><td style=""padding:11px 14px;font-weight:bold;border-bottom:1px solid #e6ede9;"">{{transaction_type}}</td></tr>
                  <tr style=""background:#f6faf7;""><td style=""padding:11px 14px;color:#5b6b63;border-bottom:1px solid #e6ede9;"">Transaction Date</td><td style=""padding:11px 14px;font-weight:bold;border-bottom:1px solid #e6ede9;"">{{transaction_date}}</td></tr>
                  <tr><td style=""padding:11px 14px;color:#5b6b63;border-bottom:1px solid #e6ede9;"">Bill Month</td><td style=""padding:11px 14px;font-weight:bold;border-bottom:1px solid #e6ede9;"">{{bill_month}} {{financial_year}}</td></tr>
                  <tr style=""background:#f6faf7;""><td style=""padding:11px 14px;color:#5b6b63;border-bottom:1px solid #e6ede9;"">Bill ID</td><td style=""padding:11px 14px;font-weight:bold;border-bottom:1px solid #e6ede9;"">{{bill_id}}</td></tr>
                  <tr><td style=""padding:11px 14px;color:#5b6b63;"">Approval Date</td><td style=""padding:11px 14px;font-weight:bold;"">{{approval_date}}</td></tr>
                </table>
              </td>
            </tr>
            <tr>
              <td style=""padding:18px 28px 6px;"">
                <div style=""font-size:14px;font-weight:bold;color:#1f6b3a;padding-bottom:8px;"">Jeevika Jankar Details</div>
                <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" border=""0"" style=""border:1px solid #dfe8e2;border-radius:8px;border-collapse:separate;font-size:14px;"">
                  <tr style=""background:#f6faf7;""><td style=""padding:11px 14px;color:#5b6b63;width:45%;border-bottom:1px solid #e6ede9;"">Jeevika Jankar ID</td><td style=""padding:11px 14px;font-weight:bold;border-bottom:1px solid #e6ede9;"">{{jj_id}}</td></tr>
                  <tr><td style=""padding:11px 14px;color:#5b6b63;border-bottom:1px solid #e6ede9;"">Name</td><td style=""padding:11px 14px;font-weight:bold;border-bottom:1px solid #e6ede9;"">{{name}}</td></tr>
                  <tr style=""background:#f6faf7;""><td style=""padding:11px 14px;color:#5b6b63;"">Mobile Number</td><td style=""padding:11px 14px;font-weight:bold;"">{{mobile_no}}</td></tr>
                </table>
              </td>
            </tr>
            <tr>
              <td style=""padding:14px 28px 4px;font-size:12px;color:#7a8a82;"">Payment updated on {{updated_on}} by {{updated_by}}</td>
            </tr>
            <tr>
              <td style=""padding:18px 28px 26px;"">
                <div style=""border-top:1px solid #e6ede9;padding-top:16px;font-size:13px;color:#5b6b63;line-height:1.6;"">
                  Payment se judi kisi bhi jaankari ke liye apne Cluster Coordinator se sampark karein.<br><br>
                  Regards,<br>
                  <strong style=""color:#1f2d26;"">Ploughman Agro Pvt. Ltd.</strong>
                </div>
              </td>
            </tr>
          </table>
          <div style=""font-size:11px;color:#8a9a92;padding-top:14px;"">Ye mail automatic bheja gaya hai, kripya iska reply na karein.</div>
        </td>
      </tr>
    </table>
  </body>
</html>
";
</script>
