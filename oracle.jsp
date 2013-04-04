<!DOCTYPE HTML>
<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.sql.*,java.util.*,java.lang.reflect.*"%>
<%!

	private static final String DRIVER = "oracle.jdbc.driver.OracleDriver";
	private static final String DB_URL = "";
	private static final String DB_USER = "";
	private static final String DB_PASS = "";

	public enum Mode {
		MAIN, QUERY, DML;
	}

	private Connection connection = null;
	private Exception lastError = null;
	private String lastQuery = "";

	public interface RowToBean<T> {
		public abstract T toBean(ResultSet rs) throws Exception;
	}

	public interface Rows {
		public abstract void row(ResultSet rs) throws Exception;
	}

	public PreparedStatement makeStatement(String sql, Object... params) throws Exception {
		PreparedStatement stmt = connection.prepareStatement(sql);
		if (params != null) {
			for(int i = 0, n = params.length; i < n; i++) {
				if (params[i] instanceof String) {
					stmt.setString(i + 1, params[i].toString());
				} else if (params[i] instanceof Integer) {
					stmt.setInt(i + 1, (Integer) params[i]);
				} else if (params[i] instanceof Float) {
					stmt.setFloat(i + 1, (Float) params[i]);
				} else if (params[i] instanceof Double) {
					stmt.setDouble(i + 1, (Double) params[i]);
				} else if (params[i] instanceof Long) {
					stmt.setLong(i + 1, (Long) params[i]);
				} else if (params[i] instanceof java.util.Date) {
					java.util.Date d = (java.util.Date) params[i];
					stmt.setDate(i + 1, new java.sql.Date(d.getTime()));
				}
			}
		}
		return stmt;
	}

	public <T> List<T> list(String sql, RowToBean<T> converter, Object... params) throws Exception {
		PreparedStatement stmt = makeStatement(sql, params);
		ResultSet rs = stmt.executeQuery();
		List<T> list = new ArrayList<T>();
		while(rs.next()) {
			list.add(converter.toBean(rs));
		}
		close(rs);
		close(stmt);
		return list;
	}

	public void jspInit() {
		try {
			Class.forName(DRIVER);
			connection = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
		} catch(Exception ex) {
			lastError = ex;
		}
	}

	public void list(String sql, Rows rows, Object... params) throws Exception {
		PreparedStatement stmt = makeStatement(sql, params);
		ResultSet rs = stmt.executeQuery();
		while(rs.next()) {
			rows.row(rs);
		}
		close(rs);
		close(stmt);
	}

	public int dml(String sql, Object... params) throws Exception {
		PreparedStatement stmt = makeStatement(sql, params);
		int re = stmt.executeUpdate();
		close(stmt);
		return re;
	}

	private void close(Connection con)  {
		if(con != null) {
			try {
				con.close();
				con = null;
			} catch(Exception ex) {
				lastError = ex;
			}
		}
	}
	private void close(PreparedStatement ps)  {
		if(ps != null) {
			try {
				ps.close();
				ps = null;
			} catch(Exception ex) {
				lastError = ex;
			}
		}
	}
	private void close(ResultSet rs)  {
		if(rs != null) {
			try {
				rs.close();
				rs = null;
			} catch(Exception ex) {
				lastError = ex;
			}
		}
	}

	public void jspDestroy() {
		close(connection);
	}

	private boolean displayError(JspWriter out) throws Exception {
		if(lastError != null) {
			out.print("<div class=\"alert alert-error alert-block\">");
			out.print("<p>Exception: " + lastError.getClass().getName() + "</p>");
			out.print("<p>Message: " + lastError.getMessage() + "</p>");
			if(lastQuery != null) out.print("<p>Query<p><pre>" + lastQuery + "</pre>");
			out.print("</div>");
			lastError = null;
			return true;
		}
		return false;
	}

	public class Col {
		public String name;
		public String type;

		public Col(String name, String type) {
			this.name = name;
			this.type = type;
		}
	}

	public class TableResult {
		public int rowCount = 0;
		public Map<String, Col> cols;
		public List<Map<String,Object>> rows;
	}
%><%

	final List<String> tables = new ArrayList<String>();

	list("select TABLE_NAME from USER_TABLES", new Rows(){
		public void row(ResultSet rs) throws Exception {
			tables.add(rs.getString("TABLE_NAME"));
		}
	});

	String modeParam = request.getParameter("mode");
	Mode mode = Mode.MAIN;
	if(modeParam != null && modeParam.length() > 0) mode = Mode.valueOf(modeParam);

	TableResult tr = null;
	int dmlResult  = -1;

	switch(mode) {
		case MAIN:

			break;

		case QUERY:
			String query = request.getParameter("sql");
			if(query == null || query.length() == 0) throw new Exception("not present SQL");
			lastQuery = query.trim();
			String queryStart = lastQuery.substring(0,4).toUpperCase();
			if (queryStart.equals("SELE") || queryStart.equals("(SEL")) {
				try {
					PreparedStatement ps = makeStatement(lastQuery);
					ResultSet rs = ps.executeQuery();
					ResultSetMetaData md = rs.getMetaData();
					int columnCount = md.getColumnCount();

					tr = new TableResult();
					tr.rowCount = 0;
					tr.cols = new LinkedHashMap<String,Col>(columnCount);
					tr.rows = new ArrayList<Map<String, Object>>();

					boolean fillName = false;
					while(rs.next()) {
						Map<String, Object> values = new LinkedHashMap<String,Object>(columnCount);
						for(int i = 1; i <= columnCount; i++) {
							String cname = md.getColumnName(i);
							String ctype = md.getColumnTypeName(i);

							if(!fillName) tr.cols.put(cname, new Col(cname,ctype));

							if(ctype.equals("VARCHAR2") || ctype.equals("CHAR") || ctype.equals("CLOB")) {
								values.put(cname, rs.getString(i));
							} else if(ctype.equals("NUMBER")) {
								values.put(cname, rs.getInt(i));
							} else if (ctype.equals("DATE")) {
								values.put(cname, rs.getDate(i));
							} else {
								out.println(cname + " ---------- " +  ctype);
							}
						}
						fillName = true;
						tr.rows.add(values);
						tr.rowCount++;
					}

					close(rs);
					close(ps);
				} catch(Exception ex) {
					lastError = ex;
				}
			} else {
				mode = Mode.DML;
				dmlResult = dml(lastQuery);
			}

			break;
	}


%>
<html lang="ko">
<head>
	<meta charset="UTF-8">
	<title>the ORACLE</title>
	<meta name="viewport" content="width=device-width, initial-scale=1.0">

	<link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/css/bootstrap-combined.min.css" rel="stylesheet">
	<link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/css/bootstrap-responsive.min.css" rel="stylesheet">
	<style type="text/css">
		body {padding-top:50px;}
		@media (max-width:979px) {
			body {padding-top:0;}
		}
		.table-fixed {table-layout: fixed;}
		.table-fixed th, .table-fixed td {overflow: hidden; white-space: nowrap; }
		.nav-list li {white-space:nowrap; overflow: hidden;}
		.table-name {font-size:.8em;}
		.table-name-button {float: left; cursor: pointer; padding-top:2px;}
		td.error {background-color: #f2dede; color: red;}
	</style>
</head>
<body>

	<div class="navbar navbar-fixed-top">
      <div class="navbar-inner">
        <div class="container">
          <button type="button" class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse">
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="brand" href="#">My Oracle Admin</a>
          <div class="nav-collapse collapse">
            <ul class="nav">
              <li class="active"><a href="<%= request.getRequestURI() %>">Home</a></li>
              <!-- <li><a href="#about">About</a></li>
              <li><a href="#contact">Contact</a></li> -->
            </ul>
          </div><!--/.nav-collapse -->
        </div>
      </div>
    </div>

	<div class="container-fluid">
		<div class="row-fluid">

			<div class="span2">
				<div class="well sidebar-nav">
					<ul class="nav nav-list">
						<!-- TABLE LIST -->
						<li class="nav-header">TABLES</li>
						<% for(String tableName : tables) { %>
						<li class=""><span class="table-name-button" onclick="pasteTableName('<%= tableName %>',event);"><i class="icon-edit"></i></span> <a href="<%= request.getRequestURI() %>?mode=TABLE&tname=<%=tableName %>" class="table-name" title="<%= tableName %>"><%= tableName %></a></li>
						<% } %>
					</ul>
				</div>
			</div>


			<div class="span10">
				<% if(!displayError(out)) { %>
					<h2 class="page-header">SQL <small>to execute</small></h2>
					<form action="<%= request.getRequestURI() %>" method="post">
					<input type="hidden" name="mode" value="<%= Mode.QUERY %>" />
						<textarea name="sql" id="sql" rows="10" class="span10"><%= lastQuery %></textarea>

						<div class="form-actions">
							<button type="submit" class="btn btn-primary">EXECUTE</button>
							<button type="reset" class="btn btn-warning">RESET</button>
						</div>
					</form>
					<% if(mode == Mode.QUERY) { %>
						<table class="table table-bordered table-condensed table-hover table-fixed">
						<caption>Rows: <span class="badge"><%= tr.rowCount %></span></caption>
						<thead>
							<tr>
								<% for(Col col : tr.cols.values()) { %>
									<th><span class="tips" title="<%= col.name %> (<%=col.type %>)"><%= col.name %> <small class="muted"><%=col.type %></small></span></th>
								<% } %>
							</tr>
						</thead>
						<tbody>
							<% for(Map<String, Object> values: tr.rows) { %>
							<tr>
								<% for(Object value: values.values()) { %>

									<% if(value == null || value.toString().equals("null")) { %>
										<td class="error">NULL</td>
									<% } else { %>
										<td><span class="tips" title="<%= value %>"><%= value %></span></td>
									<% } %>

								<% } %>
							</tr>
							<% } %>
						</tbody>
						</table>
					<% } else if (mode == Mode.DML) { %>
						<div class="alert alert-block alert-success">
							Last Query Affectd : <span class="badge badge-success"><%= dmlResult %></span>
						</div>
					<% } %>
				<% } %>
			</div>

		</div>

	</div>

	<script src="//ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js"></script>
	<script src="//ajax.googleapis.com/ajax/libs/jqueryui/1.10.2/jquery-ui.min.js"></script>
	<script src="//netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/js/bootstrap.min.js"></script>
	<script type="text/javascript">
		$('.tips').tooltip({ animation: false, placement: 'left' });
		$('.table-name').tooltip();

		function pasteTableName(tname, e) {
			$('#sql').val($('#sql').val() + tname);
		}
	</script>
</body>
</html>