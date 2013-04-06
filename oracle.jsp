<!DOCTYPE HTML>
<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="true" import="java.sql.*,java.util.*,java.lang.reflect.*"%>
<%!

	private static final String DRIVER = "oracle.jdbc.driver.OracleDriver";
	private static final String DB_URL = "";
	private static final String DB_USER = "";
	private static final String DB_PASS = "";

	public enum Mode {
		MAIN, QUERY, DML, ERROR, TABLE;
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

	public class Table {
		public Table() {

		}

		public Table(String name) {
			this(name, "");
		}

		public Table(String name, String comment) {
			this.name = name;
			this.comment = comment;
		}

		public String owner;
		public String name;
		public String comment;
		public Map<String, Col> cols;
	}

	public class Col {
		public int id;
		public String name;
		public String type;
		public String comment;
		public int size;
		public int scale;
		public boolean nullable;
		public String defaultValue;
		public int pk = 0;
		public String pkName;

		public Col() {
		}

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

	public TableResult doQuery(String sql) throws Exception {
		PreparedStatement ps = makeStatement(sql);
		ResultSet rs = ps.executeQuery();
		ResultSetMetaData md = rs.getMetaData();
		int columnCount = md.getColumnCount();

		TableResult tr = new TableResult();
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
					// out.println(cname + " ---------- " +  ctype);
				}
			}
			fillName = true;
			tr.rows.add(values);
			tr.rowCount++;
		}

		close(rs);
		close(ps);

		return tr;

	}

	public String nvl(Object val,String dv) {
		if(val == null) return dv;
		return val.toString();
	}

%><%
	final Map<String,Table> tables = new LinkedHashMap<String,Table>();
	// user_tables or all_tables ...
	list("select co.owner, tb.table_name, co.comments from user_all_tables tb left join all_tab_comments co on co.table_name = tb.table_name order by tb.table_name", new Rows(){
		public void row(ResultSet rs) throws Exception {
			Table t = new Table();
			t.owner = rs.getString("OWNER");
			t.name = rs.getString("TABLE_NAME");
			t.comment = rs.getString("COMMENTS");
			tables.put(t.name, t);
		}
	});

	String modeParam = request.getParameter("mode");
	Mode mode = Mode.MAIN;
	if(modeParam != null && modeParam.length() > 0) mode = Mode.valueOf(modeParam);
	TableResult tr = null;
	int dmlResult  = -1;
	Table theTable = null;

	// delete !! when push to git
	/* UserSession usession = (UserSession) session.getAttribute("usession");
	if(usession == null) {
		mode = Mode.ERROR;
		lastError = new Exception("require admin session");
	} */

	switch(mode) {
		case MAIN:

			break;

		case QUERY:
			String query = request.getParameter("sql");
			if(query != null && query.length() > 0) {
				lastQuery = query.trim();
				String queryStart = lastQuery.substring(0,4).toUpperCase();
				if (queryStart.equals("SELE") || queryStart.equals("(SEL")) {
					try {
						tr = doQuery(lastQuery);
					} catch(Exception ex) {
						lastError = ex;
					}
				} else {
					mode = Mode.DML;
					dmlResult = dml(lastQuery);
				}
			} else {
				lastQuery = "";
				tr = new TableResult();
			}

			break;

		case TABLE:
			String tname = request.getParameter("tname");
			if(tname == null || tname.length() == 0) throw new Exception("not present Table Name");

			// the - table
			theTable = tables.get(tname);

			// columns
			List<Col> cols = list("select c.column_id, c.owner, c.table_name, c.column_name, c.data_type, c.data_length, c.data_precision, c.data_scale, c.nullable, c.data_default, co.comments from all_tab_cols c left join ALL_COL_COMMENTS co on c.owner = co.owner and c.table_name = co.table_name and c.column_name = co.column_name where c.owner = ? and c.table_name = ? and c.hidden_column = 'NO' order by c.column_id",new RowToBean<Col>(){
				public Col toBean(ResultSet rs) throws Exception {
					Col c = new Col();
					c.id = rs.getInt("COLUMN_ID");
					c.name = rs.getString("COLUMN_NAME");
					c.type = rs.getString("DATA_TYPE");
					c.size = rs.getInt("DATA_LENGTH");
					if(rs.getInt("DATA_PRECISION") > 0) c.size = rs.getInt("DATA_PRECISION");
					c.scale = rs.getInt("DATA_SCALE");
					c.nullable = rs.getString("NULLABLE").equalsIgnoreCase("Y");
					c.defaultValue = rs.getString("DATA_DEFAULT");
					c.comment = rs.getString("COMMENTS");
					return c;
				}
			}, theTable.owner, theTable.name);

			theTable.cols = new LinkedHashMap<String,Col>(cols.size());
			for(Col c : cols) theTable.cols.put(c.name, c);

			// primary keys
			List<Col> pkCols = list("select C.column_name, c.position, c.constraint_name from USER_CONS_COLUMNS C, USER_CONSTRAINTS S where C.CONSTRAINT_NAME = S.CONSTRAINT_NAME and S.CONSTRAINT_TYPE = 'P' and C.OWNER = ? and C.TABLE_NAME = ? order by c.position", new RowToBean<Col>(){
				public Col toBean(ResultSet rs) throws Exception {
					Col c = new Col();
					c.name = rs.getString("COLUMN_NAME");
					c.pk = rs.getInt("POSITION");
					c.pkName = rs.getString("CONSTRAINT_NAME");
					return c;
				}
			}, theTable.owner, theTable.name);
			for(Col c : pkCols) {
				Col pkCol = theTable.cols.get(c.name);
				pkCol.pk = c.pk;
				pkCol.pkName = c.pkName;
			}

			// data
			try {
				tr = doQuery("select * from " + theTable.name + " where rownum < 50");
			} catch(Exception ex) {
				lastError = ex;
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
		caption {text-align: right; padding: 0 0 5px 0;}

		.table-fixed {table-layout: fixed;}
		.table-fixed th, .table-fixed td {overflow: hidden; white-space: nowrap; }
		.table-center th,
		.table-center td {text-align:center;}
		.nav-list li {white-space:nowrap; overflow: hidden;}
		.table-name {font-size:.8em;}
		.table-name-button {float: left; cursor: pointer; padding-top:2px;}
		td.error {background-color: #f2dede; color: red;}
		h1,h2,h3,h4,h5,h6{text-rendering:auto;}
		.owner {display:none;}
		.left {text-align:left;}
	</style>
</head>
<body>

<% if(mode == Mode.ERROR) { %>
	<div class="alert alert-error"><%= lastError.getMessage() %></div>
<% } else { %>

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
              <li class=" <%if(mode == Mode.MAIN) { %> active <% } %> "><a href="<%= request.getRequestURI() %>?mode=MAIN">Home</a></li>
              <li class=" <%if(mode == Mode.QUERY) { %> active <% } %> "><a href="<%= request.getRequestURI() %>?mode=QUERY">Query</a></li>
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
						<li>
							<label for="f-show-owner"><input type="checkbox" id="f-show-owner" /> owner</label>
						</li>
						<% for(Table table: tables.values()) { %>
						<li class="">
							<span class="table-name-button" onclick="pasteTableName('<%= table.name %>',event);"><i class="icon-edit"></i></span>
							<a href="<%= request.getRequestURI() %>?mode=TABLE&tname=<%=table.name %>" class="table-name" title="<%=table.owner%>.<%= table.name %><br/><%=table.comment%>"><span class="owner"><%=table.owner%>.</span><%= table.name %></a>
						</li>
						<% } %>
					</ul>
				</div>
			</div>


			<div class="span10">
				<% if(!displayError(out)) { %>

					<% if(mode == Mode.MAIN || mode == Mode.QUERY || mode == Mode.TABLE) { %>

						<% if (mode == Mode.TABLE) { %>


							<h1 class="page-header"><%= theTable.name %> <small><%= theTable.comment %></small></h1>


							<ul class="nav nav-tabs" id="tableTabs">
								<li class="active"><a href="#columns">Columns</a></li>
								<li><a href="#datas">Datas</a></li>
							</ul>

							<div class="tab-content">

								<div class="tab-pane active" id="columns">
									<table class="table table-bordered table-condensed table-hover table-center">
									<caption><span class="badge"><%= theTable.cols.size() %> Columns</span></caption>
									<thead>
										<tr>
											<th>#</th>
											<th>PK</th>
											<th>Name</th>
											<th>Type(Size)</th>
											<th>Nullable</th>
											<th>Default</th>
											<th>Comment</th>
										</tr>
									</thead>
									<tbody>
										<% for(Col c: theTable.cols.values()) { %>
										<tr>
											<td><%= c.id %></td>
											<td><% if(c.pk > 0) { %> <span class="tips badge badge-info" title="<%= c.pkName %>">PK<%= c.pk %></span> <% } %></td>
											<td><%= c.name %></td>
											<td><%= c.type %>( <%=c.size %> <% if(c.scale > 0) { %>,<%=c.scale %> <% } %> )</td>
											<td><%if( !c.nullable ) { %> <span class="badge badge-mini badge-important">Not Null</span> <% } %></td>
											<td><%= nvl(c.defaultValue, "") %></td>
											<td class="left"><%= nvl(c.comment, "") %></td>
										</tr>
										<% } %>
									</tbody>
									</table>
								</div>

								<div class="tab-pane" id="datas">
									<table class="table table-bordered table-condensed table-hover table-fixed">
									<caption><span class="badge"><%= tr.rowCount %> Rows</span></caption>
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
								</div>

							</div>





						<% } else { %>
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
								<caption><span class="badge"><%= tr.rowCount %> Rows</span></caption>
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

					<% } // QUERY || TABLE %>

				<% } // no error %>
			</div>

		</div>

	</div>

<% } %>

	<script src="//ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js"></script>
	<script src="//ajax.googleapis.com/ajax/libs/jqueryui/1.10.2/jquery-ui.min.js"></script>
	<script src="//netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/js/bootstrap.min.js"></script>
	<script type="text/javascript">
		$('.tips').tooltip({ animation: false, placement: 'left' });
		$('.table-name').tooltip({
			html: true
		});
		$('#f-show-owner').click(function(){
			var $this = $(this);
			if($this.is(':checked')) {
				$('.owner').show();
			} else {
				$('.owner').hide();
			}
		});

		function pasteTableName(tname, e) {
			$('#sql').val($('#sql').val() + tname);
		}

		$('#tableTabs a').click(function (e) {
			e.preventDefault();
			$(this).tab('show');
		});
	</script>
</body>
</html>